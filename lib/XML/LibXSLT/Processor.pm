package XML::LibXSLT::Processor;

use 5.008008;
use strict;
no strict 'refs';
use warnings;

use XML::LibXML;

our $VERSION = '1.2';

require XSLoader;
XSLoader::load('XML::LibXSLT::Processor', $VERSION);

1;
__END__
=head1 NAME

XML::LibXSLT::Processor - XSLT processor based on libxslt with additional features

=head1 SYNOPSIS

    use XML::LibXML;
    use XML::LibXSLT::Processor;

    my $xsltproc = XML::LibXSLT::Processor->new();
    my $xml = XML::LibXML->load_xml(location => 'foo.xml');
    my $result = $xsltproc->transform($xml, 'bar.xsl' => { param => 1 });
    print $result->output_string();

Multi-pass transform:

    my $result = $xsltproc->transform($xml,
        'style1.xsl' => { param => 1 },
        'style2.xsl' => { param => 1 },
        ...
    );

=head1 DESCRIPTION

This processor caches templates, documents and keys, which leads to the acceleration of the transformation, as well as much more.

Transformation benchmark:

    Test small xml:
                               Rate            XML::LibXSLT XML::LibXSLT::Processor
    XML::LibXSLT            14493/s                      --                    -35%
    XML::LibXSLT::Processor 22222/s                     53%                      --

    Test big xml:
                             Rate            XML::LibXSLT XML::LibXSLT::Processor
    XML::LibXSLT            823/s                      --                     -3%
    XML::LibXSLT::Processor 851/s                      3%                      --

Using the key() function:

    First run:
                                             Rate Search by key (not cached) Search by key (cached) Sequential search
    Search by key (not cached)             20.0/s                         --                   -40%             -100%
    Search by key (cached)                 33.3/s                        67%                     --             -100%
    Sequential search                          --                         --                     --                --

    Second run:
                                  Rate Search by key (not cached) Sequential search Search by key (cached)
    Search by key (not cached)  31.5/s                         --              -88%                  -100%
    Sequential search            254/s                       706%                --                   -99%
    Search by key (cached)     20000/s                     63440%             7780%                     --

Using the document() function:

                              Rate XML::LibXSLT Processor (Not cached) Processor (Cached)
    XML::LibXSLT            7092/s           --                   -32%               -65%
    Processor (Not cached) 10417/s          47%                     --               -48%
    Processor (Cached)     20000/s         182%                    92%                 --

Using profiler:

    my $xsltproc = XML::LibXSLT::Processor->new(
        profiler_enable => 1,
        profiler_repeat => 20,
    );
    my $result = $xsltproc->transform('t/files/test1.xml',
        't/files/multi-transform1.xsl' => { pass => "1" },
        't/files/multi-transform2.xsl' => { pass => "2" },
    );
    print $result->profiler_result->toString(2);

    <profiler repeat="20">
      <stylesheet uri="t/files/multi-transform1.xsl" time="196">
        <profile>
          <template rank="1" match="/" name="" mode="" calls="20" time="13" average="0"/>
        </profile>
        <document>
          <root>
            <pass1>1</pass1>
          </root>
        </document>
        <params>
          <param name="pass" value="1"/>
        </params>
      </stylesheet>
      <stylesheet uri="t/files/multi-transform2.xsl" time="221">
        <profile>
          <template rank="1" match="/" name="" mode="" calls="20" time="21" average="1"/>
        </profile>
        <document>
          <root>
            <prev_pass>1</prev_pass>
            <pass2>2</pass2>
          </root>
        </document>
        <params>
          <param name="pass" value="2"/>
        </params>
      </stylesheet>
    </profiler>

    Example of using profiler you can see in directory "examples/profiler".

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

Stylesheet file name.

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
