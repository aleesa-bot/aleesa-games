package Games::Gamestat;
# Stores and calculates player stats for games

use 5.018;
use strict;
use warnings;
use utf8;
use open qw (:std :utf8);
use DBI;
use English qw ( -no_match_vars );
use File::Path qw (make_path);
use Mojo::Util qw (trim);
use String::Random qw (random_string);

use Conf qw (LoadConf);
use Util qw (utf2sha1);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (SeedArtifacts);


my $c = LoadConf ();
my $dir = $c->{gamestat}->{dir};
my $gamestatdir = $c->{gamestat}->{gamestatdir};
my $dbfile = sprintf '%s/gamestat.sqlite', $gamestatdir;

# assume that there is not too much artifacts.
sub SeedArtifacts {
	open (my $AFH, '<', "$dir/archeologic_artifacts.txt") || die "No $dir/archeologic_artifacts.txt\n";
	my @arch_artifacts;

	while (my $artifact = <$AFH>) {
		next if ($artifact =~ /^\s*$/s);
		$artifact = trim ($artifact);
		push @arch_artifacts, $artifact;
	}

	close $AFH; ## no critic (InputOutput::RequireCheckedSyscalls)

	open ($AFH, '<', "$dir/fisher_artifacts.txt") || die "No $dir/fisher_artifacts.txt\n";
	my @fisher_artifacts;

	while (my $artifact = <$AFH>) {
		next if ($artifact =~ /^\s*$/s);
		$artifact = trim ($artifact);
		push @fisher_artifacts, $artifact;
	}

	close $AFH; ## no critic (InputOutput::RequireCheckedSyscalls)
	undef $AFH;

	my $tablename = random_string ('..........');
	$tablename = utf2sha1 ($tablename);

	while ($tablename =~ /^\d/s) {
		$tablename = utf2sha1 ($tablename);
	}

	$tablename =~ s/[\/_\+]/a/sg;
	$tablename = lc $tablename;

	unless (-d $gamestatdir) {
		make_path ($gamestatdir)  ||  die "Unable to create $gamestatdir: $OS_ERROR\n";
	}

	my $dbh = DBI->connect ("dbi:SQLite:$dbfile", '', '');
	$dbh->{sqlite_unicode} = 1;
	my $rows_affected = $dbh->do ('PRAGMA foreign_keys=ON') or die $dbh->errstr . "\n";
	$rows_affected = $dbh->do ('PRAGMA journal_mode=WAL') or die $dbh->errstr . "\n";

	# Open transaction
	$dbh->begin_work or die $dbh->errstr . "\n";

	my $query = <<"QUERY";
CREATE TABLE IF NOT EXISTS $tablename (
	id INT UNIQUE NOT NULL, -- artifact id
	name TEXT PRIMARY KEY   -- artifact name
);
QUERY

	$rows_affected = $dbh->do ($query) or die $dbh->errstr . "\n";
	my $sth = $dbh->prepare ("REPLACE INTO $tablename(id,name) VALUES (?,?)") or die $dbh->errstr . "\n";

	# Insert our archeological artifacts
	my $counter = 0;

	foreach my $artifact (@arch_artifacts) {
		last if ($counter == 10000);
		$sth->execute ($counter, $artifact);
		$counter++;
	}

	# Insert our fishing artifacts
	$counter = 10000;

	foreach my $artifact (@fisher_artifacts) {
		last if ($counter == 20000);
		$sth->execute ($counter, $artifact);
		$counter++;
	}

	# Add indexes
	$rows_affected = $dbh->do ("CREATE INDEX IF NOT EXISTS myartifactid ON $tablename(id)") or die $dbh->errstr . "\n";

	# Drop target table and replace it with our
	$rows_affected = $dbh->do ('DROP TABLE IF EXISTS artifacts') or die $dbh->errstr . "\n";
	$rows_affected = $dbh->do ("ALTER TABLE $tablename RENAME TO artifacts") or die $dbh->errstr . "\n";

	# Close transaction
	$dbh->commit or die $dbh->errstr . "\n";
	$dbh->disconnect or warn sprintf ('[WARN] Unable to close gamestat db, sqlite error: %s', $dbh->errstr) . "\n";
	return;
}

1;
