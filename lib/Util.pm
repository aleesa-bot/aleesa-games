package Util;

use 5.018;
use strict;
use warnings;
use utf8;
use open qw (:std :utf8);
use English qw ( -no_match_vars );

use Digest::SHA qw (sha1_base64);
use Encode;

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (utf2sha1);

sub utf2sha1 {
	my $string = shift;

	if ($string eq '') {
		return sha1_base64 '';
	}

	my $bytes = encode_utf8 $string;
	return sha1_base64 $bytes;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
