#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::Bin/../blib/lib", "$FindBin::Bin/../blib/arch");
use Test::More tests => 3;

use XML::LibXSLT::Processor;
my $xsltproc = XML::LibXSLT::Processor->new();

{
    my $result = $xsltproc->transform('t/files/join.xml', 't/files/join.xsl');

    my $str = $result->output_string();
    chomp $str;

    is
        $str,
        '<root><join_one_arg>str1</join_one_arg><join_two_args>str1,str2</join_two_args><join_node_set>str3</join_node_set><join_mix>str1,str3,str4,str5,str6</join_mix></root>',
        'Check "join" function'
    ;
}

{
    my $result = $xsltproc->transform('<root />', 't/files/trim.xsl');

    my $str = $result->output_string();
    chomp $str;

    is
        $str,
        '<root><ltrim>123   </ltrim><ltrim>123   </ltrim><ltrim/><rtrim>   123</rtrim><rtrim>   123</rtrim><rtrim/><trim>123</trim><trim>123</trim><trim/></root>',
        'Check "trim" functions'
    ;
}

SKIP: {
    my $result = $xsltproc->transform('<root />', 't/files/case.xsl');

    my $str = $result->output_string();
    chomp $str;

    skip "Case conversion functions is not available", 1 if $str eq '<root/>';

    is
        $str,
        '<root><lc>abcd</lc><uc>ABCD</uc></root>',
        'Check case conversion functions'
    ;
}
