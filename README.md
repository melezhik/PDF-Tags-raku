PDF-Tags-raku (under construction)
============

A small DOM-like API for the navigation of PDF tagged content,
simple XPath queries and basic XML serialization.

SYNOPSIS
--------

```
use PDF::Class;
use PDF::Tags;
use PDF::Tags::Elem;

my PDF::Class $pdf .= open("t/pdf/tagged.pdf");
my PDF::Tags $tags .= new: :$pdf;
my PDF::Tags::Elem $doc = $tags.root[0];
say $doc.tag; # Document

# DOM traversal
for $doc.kids {
    say .tag; # L, P, H1, P ...
}

# XPath navigation
my @tags = $doc.find('Document/L/LI[1]/LBody//*')>>.tag;
say @tags.join(','); # Reference,P,Code

```

Description
-----------

A tagged PDF contains additional markup information describing the logical
document structure. This enables PDF readers and other assistive tools to
optimize reading and access of PDF documents.

PDF tagging may also assist automated tools in traversing PDF documents and extracting content such as text and images.

This module provides a DOM  like interface for traversing Tagged PDF content,
as well as an XPath like search capability. It can be used in conjunction
with PDF::Class or PDF::API6.

Node Types
----------

- `PDF::Tags::Root` - Structure Tree root node
- `PDF::Tags::Elem` - Structure Tree descendant node
- `PDF::Tags::Mark` - Leaf content marker node
- `PDF::Tags::Text` - Text content
- `PDF::Tags::ObjRef` - A reference to a PDF::Class object (such as PDF::Annot or PDF::Field)


Scripts in this Distribution
------

##### `pdf-tag-dump.p6 --include=XPath --omit=tag --password=Xxxx --max-depth=n --marks --/render --/atts --debug t/pdf/tagged.pdf`
