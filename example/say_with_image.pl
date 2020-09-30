use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Config::Pit;
use WebService::Detox;
use YAML;


my $dt = sub { #prepare
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
my $t = <STDIN>;
my $file = "$FindBin::RealBin/img/1x1.png";

$dt->poison(
    {
        content    => $t,
        image_file => $file,
    }
);

1
