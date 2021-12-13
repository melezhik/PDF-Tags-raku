use PDF::Tags::Node::Parent;
use PDF::Tags::Node::Root;

#| Tagged PDF root node
class PDF::Tags:ver<0.0.10>
    is PDF::Tags::Node::Parent
    does PDF::Tags::Node::Root {

    use PDF::Class:ver<0.4.10+>;
    use PDF::Page;
    use PDF::NumberTree :NumberTree;
    use PDF::COS;
    use PDF::StructElem;
    use PDF::StructTreeRoot;
    use PDF::Font::Loader;
    use PDF::Content::Canvas;
    use PDF::Content::Font;
    use PDF::Content::FontObj;
    use PDF::Content::Ops :GraphicsContext;
    use PDF::Content::Matrix :&is-identity;
    use PDF::Font::Loader::FontObj;

    has Hash $.class-map         is built;
    has Hash $.role-map          is built;
    has NumberTree $.parent-tree is built;
    has Bool $.strict = True;
    has Bool $.graphics;
    has Bool $.marks = $!graphics;
    has      $.styler;
    method root { self }

    submethod TWEAK(PDF::StructTreeRoot :$cos!) {
        $!class-map = $_ with $cos.ClassMap;
        $!role-map = $_ with $cos.RoleMap;
        $!parent-tree = .number-tree
            given $cos.ParentTree //= { :Nums[] };
    }

    method read(PDF::Class:D :$pdf!, Bool :$create, |c --> PDF::Tags:D) {
        with $pdf.catalog.StructTreeRoot -> $cos {
            self.new: :$cos, :root(self.WHAT), |c;
        }
        else {
            $create
                ?? self.create(:$pdf, |c)
                !! fail "PDF document does not contain marked content";
        }
    }

    method create(
        PDF::Class:D :$pdf,
        PDF::StructTreeRoot() :$cos = PDF::StructTreeRoot.COERCE({ :Type( :name<StructTreeRoot> )}),
        |c
        --> PDF::Tags:D
    ) {
        $cos.check;

        given $pdf {
            with .catalog.StructTreeRoot {
                fail "document already contains marked content";
            }
            else {
                $_ = $cos;
            }
            .<Marked> = True
                given .Root<MarkInfo> //= {};
            .creator.push: "{self.^name}-{self.^ver}";
        }
        self.new: :$cos, :root(self.WHAT), :marks, |c
    }

    class TextDecoder {
        use PDF::Content::Ops :OpCode;
        use Method::Also;
        has Hash @!save;
        has PDF::Content::Font $!font;
        has $.graphics;
        has $.current-font;
        method current-font {
            PDF::Font::Loader.load-font: :dict($!font)
                unless $!font.font-obj ~~ PDF::Content::FontObj:D;
            $!font.font-obj;
        }

        method callback {
            sub ($op, *@args) {
                my $method = OpCode($op).key;
                self."$method"(|@args)
                    if self.can($method);
            }
        }
        method Save()      {
            @!save.push: %( :$!font );
        }
        method Restore()   {
            if @!save {
                given @!save.pop {
                    $!font = .<font>;
                }
            }
        }
        method !set-graphics-attributes($tag, $gfx) {
            if $tag.defined {
                given $gfx.CTM {
                    $tag.attributes<gm> = .join: ','
                         unless .&is-identity();
                }
                given $gfx.StrokeColor {
                    unless .key ~~ 'DeviceGray' && .value[0] =~= 0 {
                        $tag.attributes<stroke> = (.key.subst(/^Device/, ''), .value).join: ',';
                    }
                }
                given $gfx.FillColor {
                    unless .key ~~ 'DeviceGray' && .value[0] =~= 0 {
                        $tag.attributes<fill> = (.key.subst(/^Device/, ''), .value).join: ',';
                    }
                }

                if $gfx.context == GraphicsContext::Text {
                    given $gfx.TextMatrix {
                        unless .&is-identity() {
                            $tag.attributes<tm> = .join: ',';
                        }
                    }
                }
            }
        }
        method SetFont($,$?) is also<SetGraphicsState> {
            $!font = $_ with $*gfx.font-face;
        }
        method ShowText($text-encoded) {
            with $*gfx.open-tags.tail -> $tag {
                self!set-graphics-attributes: $tag, $*gfx
                    if $!graphics;
                my $text = $.current-font.decode($text-encoded, :str);
                $tag.children.push: $text;
            }
            else {
                warn $.current-font.decode($text-encoded, :str);
            }
        }
        method ShowSpaceText(List $text) {
            with $*gfx.open-tags.tail -> $tag {
                self!set-graphics-attributes: $tag, $*gfx
                    if $!graphics;
                my Str $last := ' ';
                my @chunks = $text.map: {
                    when Str {
                        $last := $.current-font.decode($_, :str);
                    }
                    when $_ <= -120 && !($last ~~ /\s$/) {
                        # assume implicit space
                        ' '
                    }
                    default { '' }
                }
                $tag.children.push: @chunks.join;
            }
            else {
                warn $text.raku;
            }
        }
        method Do($key) {
            warn "todo Do $key";
        }
    }
    constant Tags = Hash[PDF::Content::Tag];
    has Tags %!canvas-tags{PDF::Content::Canvas};

    method canvas-tags($obj --> Hash) {
        %!canvas-tags{$obj} //= do {
            $*ERR.print: '.';
            my &callback = TextDecoder.new(:$!graphics).callback;
            my $gfx = $obj.gfx: :&callback, :$!strict;
            $obj.render;
            my PDF::Content::Tag % = $gfx.tags.grep(*.mcid.defined).map: {.mcid => $_ };
        }
    }
}

=begin pod

=head2 Synopsis

  use PDF::Content::Tag :ParagraphTags;
  use PDF::Class;
  use PDF::Tags;
  use PDF::Tags::Elem;

  # create tags
  my PDF::Class $pdf .= new;

  my $page = $pdf.add-page;
  my $font = $page.core-font: :family<Helvetica>, :weight<bold>;
  my $body-font = $page.core-font: :family<Helvetica>;

  my PDF::Tags $tags .= create: :$pdf;
  my PDF::Tags::Elem $doc = $tags.Document;

  $page.graphics: -> $gfx {
      $doc.Paragraph: $gfx, {
          .say('Hello tagged world!',
               :$font,
               :font-size(15),
               :position[50, 120]);
      }
  }
  $pdf.save-as: "t/pdf/tagged.pdf";

  # read tags
  my PDF::Class $pdf .= open: "t/pdf/tagged.pdf");
  my PDF::Tags $tags .= read: :$pdf;
  my PDF::Tags::Elem $doc = $tags[0];
  say "document root {$doc.name}";
  say " - child {.name}" for $doc.kids;

  # search tags
  my PDF::Tags @elems = $tags.find('Document//*');

=head2 Description

A tagged PDF contains additional logical document structure. For example
in terms of Table of Contents, Sections, Paragraphs or Indexes.

The logical structure follows a layout model that is similar to (and is
designed to map to) other layouts such as XML, HTML, TeX and DocBook.

The leaves of the structure tree are usually references to:
 - sections Page or XObject Form content,
 - images, annotations or Acrobat forms

In addition to the structure tree, PDF documents may contain additional
page level mark-up that further assist with accessibility and organization
and processing of the content stream.

This module is under construction as an experimental tool for reading
or creating tagged PDF content.

=head2 Methods

this class inherits from L<PDF::Tags::Node::Parent> and has its method available, (including `cos`, `kids`, `add-kid`, `AT-POS`, `AT-KEY`, `Array`, `Hash`, `find`, `first` and `xml`)

=head3 method read

   method read(PDF::Class :$pdf!, Bool :$create) returns PDF::Tags

Read tagged PDF structure from an existing file that has been previously tagged.

The `:create` option creates a new struct-tree root, if one does not already exist.

=head3 method create

   method create(PDF::Class :$pdf!) returns PDF::Tags

Create an empty tagged PDF structure in a PDF.

The PDF::Tags API currently only supports writing of tagged content in read-order. Hence the
PDF object should be empty; content and tags should be co-created in read-order.

=head3 method canvas-tags

   method canvas-tags(PDF::Content::Canvas) returns Hash

Renders a canvas object (Page or XObject form) and caches
marked content as a hash of L<PDF::Content::Tag> objects,
indexed by `MCID` (Marked Content ID).

=end pod
