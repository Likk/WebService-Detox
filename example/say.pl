use strict;
use warnings;
use utf8;
use Encode;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Config::Pit;
use WebService::Detox;
use YAML;


my $dt = sub { #prepare
  local $ENV{EDITOR} ||= 'vim';

  my $pit = pit_get('de-tox.jp', require => {
      username  => 'your username on ameba.jp',
      password  => 'your password on ameba.jp',
    }
  );

  return WebService::Detox->new(
    %$pit
  );
}->();

my $res = $dt->login();
my $t = Encode::decode_utf8(<STDIN>);
$dt->poison({ content => $t});

1;
