use Test;
use PDF::Tags;
use PDF::Class;

plan 9;

my PDF::Class $pdf .= open("t/pdf/tagged.pdf");

my PDF::Tags $tags;

lives-ok {$tags .= read: :$pdf;};

my $doc = $tags[0];
is $doc.name, 'Document';
my $node = $doc[2];
is $node.name, 'H1';
is-deeply $doc[0].kids>>.name.join(' '), 'LI LI LI LI LI';
is $node.parent.name, 'Document';
is $tags.name, '#root';

is-deeply $doc.keys.sort, ('H1', 'H2', 'L', 'P');
is $doc<H1>[2].name, 'H1';
is-deeply $doc<L>[0]<LI>[1].keys.sort, ('LBody', 'Lbl');

done-testing;
