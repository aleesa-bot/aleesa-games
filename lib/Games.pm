package Games;

# Общие модули - синтаксис, кодировки итд
use 5.018; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open qw (:std :utf8);

# Модули для работы приложения
use Clone qw (clone);
use Data::Dumper qw (Dumper);
use Log::Any qw ($log);
use Mojo::Redis ();
use Mojo::IOLoop ();
use Mojo::IOLoop::Signal ();

use Conf qw (LoadConf);
use Games::Archeologist qw (Dig);
use Games::Fisher qw (Fish);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (RunGames);

my $c = LoadConf ();
my $fwd_cnt = 5;

if (defined $c->{'forward_max'}) {
	$fwd_cnt = $c->{'forward_max'};
}

# Основной парсер
my $parse_message = sub {
	my $self = shift;
	my $m = shift;
	my $answer = clone ($m);
	$answer->{from} = 'games';
	$answer->{message} = undef;

	if (defined $answer->{misc}) {
		unless (defined $answer->{misc}->{answer}) {
			$answer->{misc}->{answer} = 1;
		}

		unless (defined $answer->{misc}->{bot_nick}) {
			$answer->{misc}->{bot_nick} = '';
		}

		unless (defined $answer->{misc}->{csign}) {
			$answer->{misc}->{csign} = $c->{csign};
		}

		unless (defined $answer->{misc}->{fwd_cnt}) {
			$answer->{misc}->{fwd_cnt} = 1;
		} else {
			if ($answer->{misc}->{fwd_cnt} > $fwd_cnt) {
				$log->error ('Forward loop detected, discarding message.');
				$log->debug (Dumper $m);
				return;
			} else {
				$answer->{misc}->{fwd_cnt}++;
			}
		}

		unless (defined $answer->{misc}->{good_morning}) {
			$answer->{misc}->{good_morning} = 0;
		}

		unless (defined $answer->{misc}->{msg_format}) {
			$answer->{misc}->{msg_format} = 0;
		}

		unless (defined $answer->{misc}->{username}) {
			$answer->{misc}->{username} = '';
		}
	} else {
		$answer->{misc}->{answer}       = 1;
		$answer->{misc}->{bot_nick}     = '';
		$answer->{misc}->{csign}        = $c->{csign};
		$answer->{misc}->{fwd_cnt}      = 1;
		$answer->{misc}->{good_morning} = 0;
		$answer->{misc}->{msg_format}   = 0;
		$answer->{misc}->{username}     = '';
	}

	my $send_to = $m->{plugin};

	$log->debug ('[DEBUG] Incoming message ' . Dumper ($m));

	# Пробуем найти команды. Сообщения, начинающиеся с $answer->{misc}->{csign}
	if (substr ($m->{message}, 0, length ($answer->{misc}->{csign})) eq $answer->{misc}->{csign}) {
		my $cmd = substr $m->{message}, length ($answer->{misc}->{csign});
		my @cmds = qw (fish fishing рыба рыбка рыбалка);
		my $bingo = 0;

		while (my $check = pop @cmds) {
			if ($cmd eq $check) {
				$answer->{message} = Fish ($m->{misc}->{username});
				$bingo = 1;
				last;
			}
		}

		unless ($bingo) {
			$#cmds = -1;
			@cmds = qw (dig копать раскопки);

			while (my $check = pop @cmds) {
				if ($cmd eq $check) {
					$answer->{message} = Dig ($m->{misc}->{username});
					$bingo = 1;
					last;
				}
			}
		}
	}

	$log->debug ("[DEBUG] Sending message to channel $send_to " . Dumper ($answer));

	if (defined $answer->{message}) {
		$self->json ($send_to)->notify (
			$send_to => $answer,
		);
	}

	return;
};

my $__signal_handler = sub {
	my ($self, $name) = @_;
	$log->info ("[INFO] Caught a signal $name");

	if (defined $main::pidfile && -e $main::pidfile) {
		unlink $main::pidfile;
	}

	exit 0;
};


# main loop, он же event loop
sub RunGames {
	$log->info ("[INFO] Connecting to $c->{server}, $c->{port}");

	my $redis = Mojo::Redis->new (
		sprintf 'redis://%s:%s/1', $c->{server}, $c->{port},
	);

	$log->info ('[INFO] Registering connection-event callback');

	$redis->on (
		connection => sub {
			my ($r, $connection) = @_;

			$log->info ('[INFO] Triggering callback on new client connection');

			# Залоггируем ошибку, если соединение внезапно порвалось.
			$connection->on (
				error => sub {
					my ($conn, $error) = @_;
					$log->error ("[ERROR] Redis connection error: $error");
					return;
				},
			);

			return;
		},
	);

	my $pubsub = $redis->pubsub;
	my $sub;
	$log->info ('[INFO] Subscribing to redis channels');

	foreach my $channel (@{$c->{channels}}) {
		$log->debug ("[DEBUG] Subscribing to $channel");

		$sub->{$channel} = $pubsub->json ($channel)->listen (
			$channel => sub { $parse_message->(@_); },
		);
	}

	Mojo::IOLoop::Signal->on (TERM => $__signal_handler);
	Mojo::IOLoop::Signal->on (INT  => $__signal_handler);

	do { Mojo::IOLoop->start } until Mojo::IOLoop->is_running;
	return;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
