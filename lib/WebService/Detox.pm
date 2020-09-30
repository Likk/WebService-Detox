package WebService::Detox;

=encoding utf8

=head1 NAME

  WebService::Detox - de-tox.jp client for perl.

=head1 SYNOPSIS

  use WebService::Detox;
  my $dx = WebService::Detox->new(
    username => 'your username', #require if you login
    password => 'your password', #require if you login
  );

  $dtx->login(); #if you login
  my $tl = $dtx->public_timeline();
  for my $row (@$tl){
    warn YAML::Dump $row;
  }

=head1 DESCRIPTION

  WebService::Detox; is scraping library client for perl at de-tox.jp.

=cut

use strict;
use warnings;
use utf8;
use Carp;
use Compress::Zlib;
use Encode;
use HTTP::Request::Common;
use Web::Scraper;
use WWW::Mechanize;
use YAML;

=head1 PACKAGE GLOBAL VARIABLE

=over

=item B<VERSION>

  version.

=item B<BASE_URL>

  de-tox.jp base top url.

=back

=cut

our $VERSION   = '1.00';
our $BASE_URL  = 'http://de-tox.jp';

=head1 CONSTRUCTOR AND STARTUP

=head2 new

Creates and returns a new detox.jp object.

  my $dtx = WebService::Detox->new(
        #optional, but require when you say.
        username => q{ameba login id},
        password => q{ameba password},
  );

=cut

sub new {
    my $class = shift;
    my %args = @_;

    my $self = bless { %args }, $class;

    $self->{root}     = $BASE_URL;
    $self->{last_req} ||= time;
    $self->{interval} ||= 1;

    $self->mech();
    return $self;
}

=head1 Accessor

=over

=item B<mech>

  WWW::Mechanize object.

=back

=cut

sub mech {
    my $self = shift;
    unless($self->{__mech}){
        my $mech = WWW::Mechanize->new(
            agent => $self->{agent} || 'Linux; U; Android 2.3.3; ja-jp; SonyEricssonSO-02C Build/3.0.1.F.0.28',
            cookie_jar => {},
        );
        $self->{__mech} = $mech;
    }
    return $self->{__mech};
}

sub last_content {
    my $self = shift;
    my $arg  = shift || '';
    $self->{__last_content} ||= '';
    if($arg){
        $self->{__last_content} = $arg
    }
    return $self->{__last_content};
}

=head1 METHODS

#action

=head2 login

  sign in at de-tox.jp

    $dtx->login();

=cut

sub login {
    my $self = shift;

    $self->mech->add_header(
        'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language' => 'ja,en-us;q=0.7,en;q=0.3',
        'Accept-Encoding' => 'gzip,deflate,sdch',
    );

    {
        # amaba経由ログインのケース
        # きちんと遷移再現しないと認証エラーでる
        $self->mech->get('http://de-tox.jp/home');
        $self->mech->get('https://dauth.user.ameba.jp/login/ameba');
        my $params = {
            username => $self->{username},
            password => $self->{password},
            Submit   => 'ログイン',
        };
        $self->mech->post('https://login.user.ameba.jp/web/login', $params);
    }

}

=head2 poison

post content for de-tox.

  $dtx->poison({ content => 'hello detox'});

=cut

sub poison {
    my $self = shift;
    my $args = shift;

    $self->_get('/post');

    my $token = scraper {
        process '//input[@name="token"]', token => '@value';
        result qw/token/;
    }->scrape($self->last_content);

    my $param = {
        anonymous        => 'false', #$args->{anonymous}        ? 'true' : 'false',
        connectedTwitter => 'false', #$args->{connectedTwitter} ? 'true' : 'false',
        content          => $args->{content},
        postTwitter      => 'false',  #$args->{postTwitter}      ? 'true' : 'false',
        postType         => 'DEFAULT', #一旦defaultを入れる
        token            => $token,
    };

    if($args->{reply_id}){
      $param->{replyTargetPostId} = $args->{reply_id};
      $param->{post_type}         = 'REPLY';
    }

    my $path    = '/api/post';
    my $header  = {
        'Origin'           => 'http://de-tox.jp',
        'X-Requested-With' => 'XMLHttpRequest',
    };

    for my $key (keys %$header ){
        $self->mech->add_header($key => $header->{$key});
    }

    if( $args->{image_file} ){
        my $url = join('', $self->{root}, $path);
        warn 'postImageFile is not support.';
        #$self->mech->request(POST $url,
        #    Content_Type => 'multipart/form-data',
        #    Content      => [
        #        anonymous        => 'false', #$args->{anonymous}        ? 'true' : 'false',
        #        connectedTwitter => 'false', #$args->{connectedTwitter} ? 'true' : 'false',
        #        content          => $args->{content},
        #        postImageFile    => [ $args->{image_file} ],
        #        postTwitter      => 'false',  #$args->{postTwitter}      ? 'true' : 'false',
        #        postType         => 'DEFAULT', #$args->{postType}         || 'DEFAULT',
        #        token            => $token,
        #    ]
        #);
    }
    else{
        my $res = $self->_post($path, $param);
    }

    for my $key (keys %$header ){
        $self->mech->delete_header($key);
    }

}

=head2 republish

republish to any post.

  $dtx->republish(1);
=cut

sub republish {
    my $self    = shift;
    my $post_id = shift;

    $self->_get('/post');
    my $token = scraper {
        process '//input[@name="token"]', token => '@value';
        result qw/token/;
    }->scrape($self->last_content);

    my $header  = {
        'Origin'           => 'http://de-tox.jp',
        'X-Requested-With' => 'XMLHttpRequest',
    };

    for my $key (keys %$header ){
        $self->mech->add_header($key => $header->{$key});
    }

    my $param = {
      _method  => 'POST',
      postType => 'REPOISON',
      token    => $token,
    };
    my $path = join('/','/api', 'republish', $post_id);

    my $res = $self->_post($path, $param);

    for my $key (keys %$header ){
        $self->mech->delete_header($key);
    }
}

=head2 follow

follow user

  $dtx->follow(11448)

=cut

sub follow {
    my $self    = shift;
    my $user_id = shift;
    my $token = $self->_get_token();
    my $path  = join('/','/api', 'follow', $user_id);
    my $param = {
      _method  => 'POST',
      token    => $token,
    };

    $self->_xhr_post($path, $param);
}

=head2 public_timeline


=head1 PRIVATE METHODS

=over

=item b<_get_token>

get XSR token.

=cut

sub _get_token {
    my $self = shift;

    $self->_get('/post');
    my $token = scraper {
        process '//input[@name="token"]', token => '@value';
        result qw/token/;
    }->scrape($self->last_content);

    return $token;
}

=item b<_post>

mech post with interval.

=cut

sub _post {
  my $self = shift;
  $self->_sleep_interval;
  my $url = join('', $self->{root}, shift);
  my $res = $self->mech->post($url, @_);
  return $self->_content($res);
}

=item b<_xhr_post>

call _post with XML HTTP Request.

=cut

sub _xhr_post {
    my $self = shift;

    my $header  = {
        'Origin'           => 'http://de-tox.jp',
        'X-Requested-With' => 'XMLHttpRequest',
    };

    for my $key (keys %$header ){
        $self->mech->add_header($key => $header->{$key});
    }

    my $res = $self->_post(@_);

    for my $key (keys %$header ){
        $self->mech->delete_header($key);
    }
    return $res;
}

=item b<_get>

mech get with interval.

=cut

sub _get {
  my $self = shift;
  $self->_sleep_interval;
  my $res = $self->mech->get( join('', $self->{root}, shift), @_);
  return $self->_content($res);
}

=item b<_content>

decode content with mech.

=cut

sub _content {
  my $self = shift;
  my $res  = shift;
  my $content = $res->decoded_content();
  $self->last_content($content);
  return $content;
}


=item B<_sleep_interval>

アタックにならないように前回のリクエストよりinterval秒待つ。

=cut

sub _sleep_interval {
  my $self = shift;
  my $wait = $self->{interval} - (time - $self->{last_req});
  sleep $wait if $wait > 0;
  $self->{last_req} = time;
}


=item b<_parse>

scrape at the chat room's logs.

=cut

sub _parse {
    my $self = shift;
    my $html = shift;

    my $scraper = scraper {
        process '//div[@id="right"]/div', 'data' => scraper {
            process '//div[@class="timestamp"]',   'timestamp[]'   => 'TEXT';
            process '//span[@class="nickname"]',   'nickname[]'    => 'TEXT';
            process '//div[@class="decorated"]',   'description[]' => 'TEXT';
            process '//div[@class="permalink"]/a', 'permalink[]'   => '@href';
            process '//a[@class="speaker"]',       'speaker[]'     => '@href';
        };
        result 'data';
    };
    my $result = $scraper->scrape($html);
    my $data = [];
    for my $index (0..$#{$result->{nickname}}){
        my $row = {
            nickname    => $result->{nickname}->[$index],
            description => $result->{description}->[$index],
            timestamp   => $result->{timestamp}->[$index],
            id          => [split /message-/, $result->{permalink}->[$index]]->[1],
            speaker     => [split m{/}, $result->{speaker}->[$index]]->[1],
        };
        push @$data, $row;
    }
    return $data;
}

1;

__END__

=back

=head1 AUTHOR

likkradyus E<lt>perl {at} li.que.jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
