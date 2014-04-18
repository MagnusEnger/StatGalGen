#!/usr/bin/perl 

# Copyright 2014 Magnus Enger Libriotech

=head1 NAME

gen.pl - Generate a static image gallery

=head1 SYNOPSIS

 perl gen.pl -v --configfile myconfig.yaml

=cut

use Getopt::Long;
use YAML::Syck;
use Data::Dumper;
use File::Slurp;
use File::Find;
use Image::Thumbnail;
use Template;
use Pod::Usage;
use Modern::Perl;

# Get options
my ( $config_file, $verbose, $debug ) = get_options();

# Check that the configfile exists
if ( !-e $config_file ) {
    print "The file $config_file does not exist...\n";
    exit;
}
my $cfg = LoadFile( $config_file );
say Dumper $cfg if $debug;

# Check that the input directory exists
if ( !-e $cfg->{'in_path'} ) {
    print "The directory $cfg->{'in_path'} does not exist...\n";
    exit;
}

say "Going to sync files with rsync" if $verbose;
# Sync static files to the destination with rsync
say `rsync -r ./static/ $cfg->{'out_path'}/.static`;
# Sync files from source to destination, using rsync
say `rsync -r $cfg->{'in_path'}/ $cfg->{'out_path'}`;
# FIXME Set permissions that Apache can use
# `chmod -R 0744 $cfg->{'out_path'}`;
say "Done syncing files with rsync" if $verbose;

# Configure Template Toolkit
my $config = {
    INCLUDE_PATH => '', 
    ENCODING => 'utf8'  # ensure correct encoding
};
# create Template object
my $tt2 = Template->new( $config ) || die Template->error(), "\n";

find( \&wanted, $cfg->{'out_path'} );

my %foundfiles;
sub wanted {

    # Skip hidden files and HTML files
    if ( $File::Find::dir eq '.'       ||
         $File::Find::dir eq '.static' ||
         $File::Find::dir =~ m|/\.|    ||
         $_ eq '.thumb'                || 
         $_ =~ m/html/i ) {
        return;
    }

    # Find the dirs that come after the base dir
    $File::Find::dir =~ /$cfg->{'out_path'}(.*)/;
    my $reldir = $1;
    if ( $reldir eq '' ) { $reldir = '/'; }

    if ( $verbose ) {
        say '-----';
        say $File::Find::dir;
        say $_;
        say $File::Find::name;
        say $reldir;
    }
    
    $foundfiles{ $reldir }{ 'fulldir' } = $File::Find::dir;
    $foundfiles{ $reldir }{ 'reldir' } = $reldir;
    if ( -f $File::Find::name ) {
        if ( $_ eq 'index.html' ) {
            return;
        }
        push @{ $foundfiles{ $reldir }{ 'files' } }, $_;
    } elsif ( -d $File::Find::name ) {
        if ( $_ eq '.' || $_ eq '.static' || $_ =~ m|/\.| ) {
            return;
        }
        push @{ $foundfiles{ $reldir }{ 'dirs' } }, $_;
    }
    
}

say Dumper \%foundfiles if $debug;

foreach my $dir ( sort keys %foundfiles ) {

    say $dir if $verbose;
    
    my $fulldir   = $foundfiles{ $dir }{ 'fulldir' };
    my $indexfile = $fulldir . '/index.html';
    say $indexfile if $verbose;
    $tt2->process( 'templates/page.tt', $foundfiles{ $dir }, $indexfile ) || die $tt2->error();
    
    # Check if there are any actual images and loop through them 
    if ( $foundfiles{ $dir }{ 'files' } ) {
        my $thumbdir = $fulldir . '/.thumb';
        if ( !-e $thumbdir ) {
            mkdir $thumbdir or say $!;
        }
        foreach my $file ( @{ $foundfiles{ $dir }{ 'files' } } ) {
            # Add thumbnils - Image::Thumbnail
            my $t = new Image::Thumbnail(
                module     => 'GD',
                size       => 200,
                create     => 1,
                input      => $foundfiles{ $dir }{ 'fulldir' } . '/' . $file,
                outputpath => $foundfiles{ $dir }{ 'fulldir' } . '/.thumb/' . $file,
            );
            say Dumper $t if $debug;
            # Add one HTML page per image
            my $imgfile = "$fulldir/$file.html";
            $foundfiles{ $dir }{ 'img' } = $file;
            # $foundfiles{ $dir }{ 'fulldir' } .= "/$file";
            $tt2->process( 'templates/page.tt', $foundfiles{ $dir }, $imgfile ) || die $tt2->error();
        }
    }

}

=head1 OPTIONS

=over 4

=item B<-c, --configfile>

Path to configfile.

=item B<-v --verbose>

More verbose output.

=item B<-d --debug>

Even more verbose output.

=item B<-h, -?, --help>

Prints this help message and exits.

=back
                                                               
=cut

sub get_options {

    # Options
    my $config_file = '';
    my $verbose     = '';
    my $debug       = '';
    my $help        = '';

    GetOptions (
        'i|configfile=s' => \$config_file,
        'v|verbose'      => \$verbose,
        'd|debug'        => \$debug,
        'h|?|help'       => \$help
    );

    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -c, --configfile required\n", -exitval => 1 ) if !$config_file;

    return ( $config_file, $verbose, $debug );

}

=head1 COPYRIGHT AND LICENSE

Copyright 2014 Magnus Enger

This software is free software; you may redistribute it and/or modify
it under the same terms as Perl itself.

=cut
