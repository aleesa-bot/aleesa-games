package Games::Archeologist;

use 5.018; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open qw (:std :utf8);
use English qw ( -no_match_vars );
use DBI ();
use Log::Any qw ($log);
use Math::Random::Secure qw (irand);

use Conf qw (LoadConf);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (Dig);

my $c = LoadConf ();
my $gamestatdir = $c->{gamestat}->{gamestatdir};
my $dbfile = sprintf '%s/gamestat.sqlite', $gamestatdir;


sub getRandomArtifact {
	my $dbh;
	$dbh = DBI->connect ("dbi:SQLite:$dbfile", '', '') or do {
		$log->error (sprintf '[ERROR] Unable to get random artifact, sqlite error: %s', $dbh->errstr);
		return undef;
	};

	$dbh->{sqlite_unicode} = 1;

	my $rows_affected = $dbh->do ('PRAGMA foreign_keys=ON') or do {
		$log->error (sprintf '[ERROR] Unable to get random artifact, sqlite error: %s', $dbh->errstr);
		return undef;
	};

	$rows_affected = $dbh->do ('PRAGMA journal_mode=WAL') or do {
		$log->error (sprintf '[ERROR] Unable to get random artifact, sqlite error: %s', $dbh->errstr);
		return undef;
	};

	my $ary_ref = $dbh->selectall_arrayref ('SELECT name FROM artifacts WHERE id > 0 AND id < 10000') or do {
		$log->error (sprintf '[ERROR] Unable to get random artifact, sqlite error: %s', $dbh->errstr);
		return undef;
	};

	$dbh->disconnect or $log->warn (sprintf '[WARN] Unable to close gamestat db, sqlite error: %s', $dbh->errstr);

	return $ary_ref->[irand ($#{ $ary_ref } + 1)]->[0];
}

sub Dig {
	my $name = shift;

	my @location = (
		'в архивах',
		'в гималаях',
		'в интернете',
		'в кармане',
		'в клумбе',
		'в лунном кратере',
		'во льдах арктики',
		'в морге',
		'в окрестностях погоста',
		'в песочнице',
		'в пустыне Гоби',
		'в пустыне Сахаре',
		'в русле высохшей реки',
		'в собственной памяти',
		'в старом сортире',
		'в углу',
		'в цветочном горшке',
		'на бабушкином огороде',
		'на винчестере',
		'на горе Арарат',
		'на горном плато',
		'на дне моря',
		'на необитаемом острове',
		'на первом слое сумрака',
		'на просторах Украины',
	);

	my $find_probability = irand 100;
	my $success_probability = irand 100;
	my $artifact_age = irand 15000;

	if ($find_probability <= 20) {
		return sprintf 'По уши закопавшись %s, %s, нифига вы не выкопали! Может повезет в другом месте?', $location[irand ($#location + 1)], $name;
	}

	my $phrase = sprintf "Вы начали раскопки %s и усиленно роете лопатами, экскаватором...\n", $location[irand ($#location + 1)];
	$phrase .= "Вам кажется, что ваш совочек ударился обо что-то твердое. Может, это клад?!\n\n";
	my $artifact = getRandomArtifact();

	if ($success_probability <= 25) {
		$phrase .= sprintf '%s стал лучшим археологом, выкопав %s! возраст артефакта - %s лет!', $name, $artifact, $artifact_age;
	} else {
		$phrase .= sprintf "Поздравляю, %s! Вы только что выкопали %s, возраст - %s лет!\n", $name, $artifact, $artifact_age;
		$phrase .= sprintf 'Извини, %s, но на артефакт это не тянет! Однако, попытка хорошая!', $name;
	}

	return $phrase;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
