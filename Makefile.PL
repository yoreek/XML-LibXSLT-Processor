# Makefile.PL for XML::LibXSLT::Processor.
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
# Copyright 2012 Yuriy Ustushenko, all rights reserved.
#
# Derived from the module XML::LibXSLT
# Copyright 2001-2003 AxKit.com Ltd., 2002-2006 Christian Glahn, 2006-2009 Petr Pajas

use 5.008008;
use warnings;
use strict;
use ExtUtils::MakeMaker;
use Config;
use Symbol;
use File::Spec;
use Cwd;

our (%PARAMS, $DEBUG, %CONFIG);

WriteMakefile(
    NAME          => 'XML::LibXSLT::Processor',
    VERSION_FROM  => 'lib/XML/LibXSLT/Processor.pm', # finds $VERSION
    ABSTRACT_FROM => 'lib/XML/LibXSLT/Processor.pm', # retrieve abstract from module
    AUTHOR        => 'Yuriy Ustushenko <yoreek@yahoo.com>',
    LICENSE       => "perl",
    PREREQ_PM     => {
        'XML::LibXML'  => 1.62,
        'XML::LibXML'  => 0,
    },
    get_config(),
);

sub get_config {
    parse_params();

    build_libxsltp();

    return %CONFIG;
}

sub build_libxsltp {
    my $start_dir      = cwd();
    my $libxsltp_path  = File::Spec->catdir($start_dir, 'libxsltp');
    my $libxsltp_build = File::Spec->catdir($libxsltp_path, 'libxsltp', '.libs');

    my $makefile;
    open(my $fh, '<', 'libxsltp/libxsltp/Makefile') or die "Can't open make file";
    {
        local $/;
        $makefile = <$fh>;
    }
    close $fh;

    my %vars;
    @vars{qw(LIBXSLT_CFLAGS LIBXSLT_LIBS THREAD_LIBS OPENSSL_LIBS)} = ();
    foreach my $line (split /[\n\r]+/, $makefile) {
        if ($line =~ /^(\w+)\s*=\s*(.*)/) {
            my ($name, $value) = ($1, $2);
            next unless exists $vars{$name} && $value;
            $vars{$name} = $value;
        }
    }

    $CONFIG{LIBS} = join(' ', grep { $_ } ($CONFIG{LIBS}, @vars{qw( LIBXSLT_LIBS THREAD_LIBS OPENSSL_LIBS )}));
    $CONFIG{INC}  = join(' ', grep { $_ } ($CONFIG{INC}, @vars{qw( LIBXSLT_CFLAGS )}, "-I$libxsltp_path"));

    -e $libxsltp_path or die "Path '$libxsltp_path' is not exists";

    chdir $libxsltp_path;

    if ($DEBUG) {
        system("./configure --enable-debug") == 0 or die "Can't configure libxsltp";
    }
    else {
        system("./configure") == 0 or die "Can't configure libxsltp";
    }

    system( $Config{make} ) == 0 or die "Can't build libxsltp";

    chdir $start_dir;

    $CONFIG{OBJECT} = "Processor.o $libxsltp_build/libxsltp.a";
    use Data::Dumper;
    print Dumper \%CONFIG;
}


# read extra configurations from the commandline
sub parse_params {
    @PARAMS{qw(DEBUG DEFINE INC LIBS XMLPREFIX NO_THREADS LDFLAGS)} = ();

    @ARGV = grep {
        my ($key, $val) = split(/=/, $_, 2);
        if (exists $PARAMS{$key}) {
            $PARAMS{$key} = $val; 0
        } else { 1 }
    } @ARGV;

    # switch Debugging messages on
    $DEBUG = delete $PARAMS{DEBUG};
}
