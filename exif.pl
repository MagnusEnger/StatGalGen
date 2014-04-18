#!/usr/bin/perl

use Image::EXIF;
use Data::Dumper;

die "Usage: perl exif.pl <pathtoimage>" unless $ARGV[0];

my $exif = Image::EXIF->new( $ARGV[0] );
my $all_info = $exif->get_all_info(); # hash reference
print Dumper($all_info);
