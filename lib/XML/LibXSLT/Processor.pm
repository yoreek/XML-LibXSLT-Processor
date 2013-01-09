package XML::LibXSLT::Processor;

use 5.008008;
use strict;
no strict 'refs';
use warnings;

our $VERSION = '1.1';

require XSLoader;
XSLoader::load('XML::LibXSLT::Processor', $VERSION);

1;
__END__
=head1 NAME

XML::LibXSLT::Processor - XSLT processor based on libxslt with additional features

=head1 SYNOPSIS

    use XML::LibXSLT::Processor;
    use XML::LibXML;

    my $xsltproc = XML::LibXSLT::Processor->new();
    my $xml = XML::LibXML->load_xml(location => 'foo.xml');
    my $result = $xsltproc->transform($xml, 'bar.xsl' => { param => 1 });
    print $result->output_string();

=head1 DESCRIPTION

This processor caches templates, documents and keys, which leads to the acceleration of the transformation, as well as much more.

=head1 METHODS

=head2 new

    my $xsltproc = XML::LibXSLT::Processor->new(%options);

Creates instance of the XSLT processor.

Valid options are:

=over

=item * B<stylesheet_max_depth> [ = 250 ]

    my $xsltproc = XML::LibXSLT::Processor->new(
        stylesheet_max_depth => 1000
    );

This option sets the maximum recursion depth for a stylesheet.

=item * B<stylesheet_caching_enable> [ = 1 ]

    my $xsltproc = XML::LibXSLT::Processor->new(
        stylesheet_caching_enable => 1
    );

Set this option to "1" to enable stylesheet caching.

=item * B<document_caching_enable> [ = 1 ]

    my $xsltproc = XML::LibXSLT::Processor->new(
        document_caching_enable => 1
    );

Set this option to "1" to enable XML document caching.

=item * B<keys_caching_enable> [ = 1 ]

    my $xsltproc = XML::LibXSLT::Processor->new(
        keys_caching_enable => 1
    );

Set this option to "1" to enable keys caching.

=item * B<profiler_enable> [ = 0 ]

    my $xsltproc = XML::LibXSLT::Processor->new(
        profiler_enable => 1
    );

Set this option to "1" to enable collection the profile information.

=item * B<profiler_stylesheet> [ = undef ]

    my $xsltproc = XML::LibXSLT::Processor->new(
        profiler_stylesheet => 'profiler.xsl'
    );

If parameter is specified, the profile information added with this template in the resulting HTML document.

=item * B<profiler_repeat> [ = 1 ]

    my $xsltproc = XML::LibXSLT::Processor->new(
        profiler_repeat => 1
    );

This option sets the number of repeats transformations.

=back

=head2 transform(xml, stylesheet => \%params, stylesheet => \%params, ...)

    my $xml = XML::LibXML->load_xml(location => 'foo.xml');
    my $result = $xsltproc->transform($xml, 'bar.xsl' => { param => 1 });
    print $result->output_string();

    my $result = $xsltproc->transform('foo.xml', 'bar.xsl' => { param => 1 });
    print $result->output_string();

    my $result = $xsltproc->transform('<root/>', 'bar.xsl' => { param => 1 });
    print $result->output_string();

Transforms the passed in XML document, and returns XML::LibXSLT::Processor::Result.

Paramaters are:

=over

=item * B<xml>

XML document may be specified as an XML::LibXML::Document object, a file name or a string.

=item * B<stylesheet>

This parameter can be either a filename or an URL.

=back

=head1 AUTHOR

=over

Yuriy Ustushenko, E<lt><yoreek@yahoo.com>E<gt>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 Yuriy Ustushenko

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
