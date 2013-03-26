#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::Bin/../blib/lib", "$FindBin::Bin/../blib/arch");
use Test::More tests => 3;

my $class = 'XML::LibXSLT::Processor';

# create instance
{
    use_ok($class);
    my $xsltproc = $class->new();
    isa_ok($xsltproc, $class);
}

# destroy $xsltproc when $result is using
{
    my $xsltproc = $class->new();
    my $result = $xsltproc->transform('t/files/test1.xml',
        't/files/test1.xsl' => { param1 => "'PARAM1_VALUE'" }
    );
    my $str = $result->output_string();
    chomp $str;

    $xsltproc = undef;

    is
        $str,
        '<root><param1>PARAM1_VALUE</param1><tag1>TAG1_VALUE</tag1></root>'
    ;
}
