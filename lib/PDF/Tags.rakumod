use PDF::Tags::Node::Parent;
use PDF::Tags::Node::Root;

#| Tagged PDF root node
class PDF::Tags:ver<0.1.9>
    is PDF::Tags::Node::Parent
    does PDF::Tags::Node::Root {

    use PDF::Class:ver<0.4.10+>;
    use PDF::NumberTree :NumberTree;
    use PDF::StructElem;
    use PDF::StructTreeRoot;

    has Hash $.class-map         is built;
    has Hash $.role-map          is built;
    has NumberTree $.parent-tree is built;
    has      $.styler;
    has Lock $!lock handles<protect> .= new;
    method root { self }
    method marks { True }

    submethod TWEAK(PDF::StructTreeRoot :$cos!) {
        $!class-map = $_ with $cos.ClassMap;
        $!role-map = $_ with $cos.RoleMap;
        $!parent-tree = .number-tree
            given $cos.ParentTree //= { :Nums[] };
    }

    method read(|c) {
        my constant Reader = 'PDF::Tags::Reader';
        CATCH {
            when X::CompUnit::UnsatisfiedDependency {
                fail "{Reader.raku} needs to be installed to read tagged PDF files";
            }
        }
        require ::(Reader);
        ::(Reader).read(|c);
    }

    method create(
        PDF::Class:D :$pdf,
        PDF::StructTreeRoot() :$cos = { :Type( :name<StructTreeRoot> )},
        :%role-map,
        :%class-map,
        |c
        --> PDF::Tags:D
    ) {
        $cos.RoleMap = %role-map if %role-map;
        $cos.ClassMap = %class-map if %class-map;
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

    # Set the page to a given index.
    # To create identical PDF files. Mostly for thread-testing purposes.
    method set-page-index(PDF::Page:D $Pg, UInt:D $idx) {
        self.protect: {
            $Pg.StructParents = $idx;
            $!parent-tree[$idx] //= [];
        }
    }

    method canvas-tags(|) {
        fail "PDF::Tags::Reader is required to read PDF tags";
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
  my $font = $pdf.core-font: :family<Helvetica>, :weight<bold>;
  my $body-font = $pdf.core-font: :family<Helvetica>;

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
  $pdf.save-as: "tagged.pdf";

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

=head3 method create

   method create(PDF::Class :$pdf!) returns PDF::Tags

Create an empty tagged PDF structure in a PDF.

=end pod
