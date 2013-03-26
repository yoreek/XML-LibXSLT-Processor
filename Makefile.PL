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
use lib qw(inc);
use Devel::CheckLib;
use ExtUtils::MakeMaker;
use Config;
use Symbol;
use File::Spec;
use Cwd;

our (%PARAMS, $DEVNULL, $is_Win32, $DEBUG, %LIBS_AVAILABLE);

our @COMMON_LIB_PATH = (
    '/usr/lib',
    '/usr/local/lib',
    '/usr/pkg/lib',
    '/opt/local/lib',
);

our @COMMON_INC_PATH = (
    '/usr/include',
    '/usr/local/include',
    '/usr/pkg/include',
    '/opt/local/include',
);

our @REQUIRED_LIBS = (
    {
        name      => 'xml2',
        mandatory => 1,
        configs   => [
            {
                lib     => sub {
                    my $results = $is_Win32 ? undef : backtick(
                        join('/bin/', grep { $_ } ($ENV{XMLPREFIX} || $PARAMS{XMLPREFIX}, 'xml2-config')),
                        '--libs',
                    );
                    $results ? [ map { substr($_, 2) } grep { $_ =~ /^-l/ } split(/\s+/, $results) ] : undef;
                },
                libpath => sub {
                    my $results = $is_Win32 ? undef : backtick(
                        join('/bin/', grep { $_ } ($ENV{XMLPREFIX} || $PARAMS{XMLPREFIX}, 'xml2-config')),
                        '--libs',
                    );
                    $results ? [ map { substr($_, 2) } grep { $_ =~ /^-L/ } split(/\s+/, $results) ] : undef;
                },
                incpath => sub {
                    my $results = $is_Win32 ? undef : backtick(
                        join('/bin/', grep { $_ } ($ENV{XMLPREFIX} || $PARAMS{XMLPREFIX}, 'xml2-config')),
                        '--cflags',
                    );
                    $results ? [ map { substr($_, 2) } grep { $_ =~ /^-I/ } split(/\s+/, $results) ] : undef;
                },
                header  => 'libxml/parser.h',
            },
            {
                lib => 'xml2 m z',
                libpath => \@COMMON_LIB_PATH,
                incpath => [
                    @COMMON_INC_PATH,
                    '/usr/include/libxml2',
                    '/usr/local/include/libxml2',
                    '/usr/pkg/include/libxml2',
                    '/opt/local/include/libxml2',
                ],
                header  => 'libxml/parser.h',
            },
        ],
    },
);

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

    check_libs();

    build_libxsltp();

    return generate_config();
}

sub generate_config {
    return unless scalar %LIBS_AVAILABLE;

    my (%config, %summary_config);
    my @options = qw(lib libpath incpath);

    foreach my $lib_config (values %LIBS_AVAILABLE) {
        foreach my $option (@options) {
            my $value = $lib_config->{$option} or next;
            $value = [ split(/\s+/, $value) ] unless ref $value;
            $config{$option}{$_} = 1 for @$value;
        }
    }

    if ( $PARAMS{LIBS} ) {
        $summary_config{LIBS} = [ $PARAMS{LIBS} ];
    }
    else {
        my @libs = (
            # order is important!
            ( map { "-L$_" } keys %{ $config{libpath} || {} } ),
            ( map {
                $Config{cc} eq 'cl' && $_ !~ /\.lib$/ ? "-l$_.lib" : "-l$_"
              } keys %{ $config{lib} || {} }
            ),
        );
        $summary_config{LIBS} = \@libs if scalar @libs;
    }

    if ( $PARAMS{INC} ) {
        $summary_config{INC} = [ $PARAMS{INC} ];
    }
    else {
        my @inc = map { "-I$_" } keys %{ $config{incpath} || {} };
        $summary_config{INC} = \@inc if scalar @inc;
    }

    my @define = map { "-DXMLHASH_HAVE_" . uc($_) } keys %LIBS_AVAILABLE;
    $summary_config{DEFINE} = \@define if scalar @define;

    # convert array to string
    $summary_config{$_} = join(' ', @{ $summary_config{$_} }) for keys %summary_config;

    return %summary_config;
}

sub check_libs {
    my @options = qw(lib libpath incpath header function);
    foreach my $info (@REQUIRED_LIBS) {
        my $lib = $info->{name};
        foreach my $lib_config (@{ $info->{configs} }) {
            my %config;

            @config{@options} = map {
                my $results = $lib_config->{$_};
                $results = ($results and ref($results) eq 'CODE') ? &$results() : $results;
                ($results and $_ ne 'function' and !ref($results))
                    ? [ split(/\s+/, $results) ]
                    : $results
                ;
            } @options;

            next unless $config{lib};

            print "Checking for '$lib'... ";

            delete $config{$_} for grep { !$config{$_} } keys %config;
            if ( $PARAMS{LIBS} ) {
                delete $config{lib};
                delete $config{libpath};
                $config{LIBS} = $PARAMS{LIBS};
            }
            if ( $PARAMS{INC} ) {
                delete $config{incpath};
                $config{INC} = $PARAMS{INC};
            }

            if ( check_lib(debug => $DEBUG, %config) ) {
                print "yes\n";
                $LIBS_AVAILABLE{$lib} = \%config;
                last;
            }

            print "no\n";
        }

        if ($info->{mandatory} && !$LIBS_AVAILABLE{$lib}) {
            print STDERR <<"DEATH";
'$lib' library not found
Try setting LIBS and INC values on the command line

Also, you may try to run perl Makefile.PL with the DEBUG=1 parameter
to see the exact reason why the detection of '$lib' installation
failed or why Makefile.PL was not able to compile a test program.
DEATH
            exit 1;
        }
    }
}

sub build_libxsltp {
    my $start_dir      = cwd();
    my $libxsltp_path  = File::Spec->catdir($start_dir, 'libxsltp');
    my $libxsltp_build = File::Spec->catdir($libxsltp_path, 'libxsltp', '.libs');

    unless (-e $libxsltp_path) {
        die "Can't git clone libxsltp repository";
    }

    chdir $libxsltp_path;

    if ($DEBUG) {
        system("./configure --enable-debug") == 0 or die "Can't configure libxsltp";
    }
    else {
        system("./configure") == 0 or die "Can't configure libxsltp";
    }

    system( $Config{make} ) == 0 or die "Can't build libxsltp";

    $LIBS_AVAILABLE{xsltp}{lib}     = 'xsltp';
    $LIBS_AVAILABLE{xsltp}{libpath} = $libxsltp_build;
    $LIBS_AVAILABLE{xsltp}{incpath} = $libxsltp_path;

    chdir $start_dir;
}


# read extra configurations from the commandline
sub parse_params {
    $is_Win32 = ($^O =~ /Win32/);
    if ($is_Win32) {
        $DEVNULL = 'DEVNULL';
    }
    else {
        $DEVNULL = eval { File::Spec->devnull };
        if ($@) { $DEVNULL = '/dev/null' }
    }

    @PARAMS{qw(DEBUG DEFINE INC LIBS XMLPREFIX NO_THREADS LDFLAGS)} = ();

    @ARGV = grep {
        my ($key, $val) = split(/=/, $_, 2);
        if (exists $PARAMS{$key}) {
            $PARAMS{$key} = $val; 0
        } else { 1 }
    } @ARGV;

    # switch Debugging messages on
    $DEBUG = delete $PARAMS{DEBUG};

    if ( $DEBUG and $is_Win32 ) {
        warn "win32 compile\n";
    }
}

sub backtick {
    my $command = join(' ', @_);
    if ($DEBUG) {
        print "Cmd: $command \n";
        my $results = `$command`;
        if ($? != 0) {
            warn "Backticks call to '$command' failed";
            return;
        }
        chomp $results;
        return $results;
    }

    local *OLDOUT;
    local *OLDERR;

    open(OLDOUT, ">&STDOUT");
    open(OLDERR, ">&STDERR");
    open(STDOUT, ">$DEVNULL");
    open(STDERR, ">$DEVNULL");
    my $results = `$command`;
    my $retval = $?;
    open(STDOUT, ">&OLDOUT");
    open(STDERR, ">&OLDERR");
    if ($retval != 0) {
        if ($DEBUG) {
            warn "backticks call to '$command' failed";
        }
        return;
    }
    chomp $results;
    return $results;
}
