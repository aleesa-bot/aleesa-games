package Games::Fisher;

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
our @EXPORT_OK = qw (Fish);

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

	my $ary_ref = $dbh->selectall_arrayref ('SELECT name FROM artifacts WHERE id > 9999 AND id < 20000') or do {
		$log->error (sprintf '[ERROR] Unable to get random artifact, sqlite error: %s', $dbh->errstr);
		return undef;
	};

	$dbh->disconnect or $log->warn (sprintf '[WARN] Unable to close gamestat db, sqlite error: %s', $dbh->errstr);

	return $ary_ref->[irand ($#{ $ary_ref } + 1)]->[0];
}


sub Fish {
	my $name = shift;

	my @location = (
		'в поток',
		'в озеро',
		'в реку',
		'в северный ледовитый океан',
		'в индийский океан',
		'в биде',
		'в детский плавательный бассейн',
		'в туалет',
		'в кучу рвоты',
		'в лужу мочи',
		'в раковину',
		'в слив ванной',
		'в лужу грязи',
		'в ведро воды',
		'в бутылку с водкой',
		'в ванную',
		'в бочку с дождевой водой',
		'в аквариум',
		'в сугроб',
		'в водопад',
		'в чашку кофе',
		'в стакан молока',
		'в черную дыру',
		'дно Удомельского реактора',
		'на Марс',
		'в соседнюю галактику',
		'к соседу на балкон',
		'далеко-далеко',
		'далеко и надолго',
		'на крышу дома',
	);

	my @material = (
		'бамбуковую',
		'фибергласовую',
		'карбоновую',
		'композитную',
	);

	my $find_probability = irand 100;
	my $success_probability = irand 100;
	my $weight = irand 7000;

	my $phrase = sprintf "Вы забрасываете %s удочку %s.\nВы чувствуете поклёвку и начинаете быстро тащить что-то.\n", $material[irand ($#material + 1)], $location[irand ($#location + 1)];

	if ($find_probability <= 20) {
		$phrase .= sprintf 'Черт, твоя рыбка сорвалась, %s! Не беда, может потом повезет?', $name;
		return $phrase;
	}

	my $artifact = getRandomArtifact ();
	$phrase .= sprintf "Поздравляю, %s! Вы только что поймали %s! аж на %d кило!\n\n", $name, $artifact, $weight;

	if ($success_probability <= 25) {
		$phrase .= sprintf 'Ё-мое!!! А это ведь новый рекорд! Продолжай в том же духе, %s!', $name;
	} else {
		$phrase .= sprintf 'Извини, %s, но это не новый рекорд! Однако, хорошая попытка!', $name;
	}

	return $phrase;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
