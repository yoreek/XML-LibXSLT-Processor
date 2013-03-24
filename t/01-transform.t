#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::Bin/../blib/lib", "$FindBin::Bin/../blib/arch");
use Test::More tests => 6;

my $class = 'XML::LibXSLT::Processor';

# create instance
{
    use_ok($class);
    my $xsltproc = $class->new();
    isa_ok($xsltproc, $class);
}

# cached
{
    my $xsltproc = $class->new();
    my $result = $xsltproc->transform('t/files/test1.xml',
        't/files/test1.xsl' => { param1 => "'PARAM1_VALUE'" }
    );

    is
        $result->output_string(),
        '<root><param1>PARAM1_VALUE</param1><tag1>TAG1_VALUE</tag1></root>',
        'Transform with cache enabled'
    ;
}

# not cached
{
    my $xsltproc = $class->new(stylesheet_caching_enable => 0);
    my $result = $xsltproc->transform('t/files/test1.xml',
        't/files/test1.xsl' => { param1 => "'PARAM1_VALUE'" }
    );

    is
        $result->output_string(),
        '<root><param1>PARAM1_VALUE</param1><tag1>TAG1_VALUE</tag1></root>',
        'Transform with cache disabled'
    ;
}

# multi-transform
{
    my $xsltproc = $class->new(stylesheet_caching_enable => 1);
    my $result = $xsltproc->transform('t/files/test1.xml',
        't/files/multi-transform1.xsl' => { pass => "1" },
        't/files/multi-transform2.xsl' => { pass => "2" },
    );

    is
        $result->output_string(),
        '<root><prev_pass>1</prev_pass><pass2>2</pass2></root>',
        'Multi-transform'
    ;
}

# profiling
{
    my $xsltproc = $class->new(
        profiler_enable     => 1,
#        profiler_stylesheet => 't/files/profiler.xsl',
    );
    my $result = $xsltproc->transform('t/files/test1.xml',
        't/files/multi-transform1.xsl' => { pass => "1" },
        't/files/multi-transform2.xsl' => { pass => "2" },
    );

    like
        $result->profiler_result()->toString(0),
        qr/<profiler/,
        'Profiling'
    ;
}
