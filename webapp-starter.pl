#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Getopt::Long;
use Pod::Usage;
use Data::Section::Simple qw/get_data_section/;
use Text::Xslate;
use File::Path qw/mkpath/;
use File::Basename;
use Text::Xslate::Syntax::TTerse;

GetOptions(
    'h|help' => \my $help,
);
pod2usage() if $help;
my $appname = shift @ARGV or pod2usage();

&main;exit;

sub main {
    my $data = get_data_section();
    my $tx = Text::Xslate->new(
        path => [ $data ],
        syntax => 'TTerse',
        tag_start => '<%',
        tag_end   => '%>',
    );

    print "making $appname\n";
    (my $appdir = $appname) =~ s/::/-/g;
    mkdir($appdir);
    chdir($appdir);
    (my $path = $appname) =~ s!::!/!g;
    (my $package = $appname);

    my $opt = {
        name      => $appdir,     # My-App
        path      => $path,       # My/App
        'package' => $package,    # My::App
    };

    while (my ($fname, $val) = each %$data) {
        $fname =~ s!^\s+!!;
        $fname =~ s{\s+$}{};
        if ($val =~ /\S/) {
            print "  rendering $fname\n";
            my $dstpath = $tx->render_string($fname, $opt);
            mkpath(dirname($dstpath));

            open my $fh, '>:utf8', $dstpath or die "cannot open file: $dstpath: $!";
            print {$fh} $tx->render($fname, $opt);
            close $fh;
        } else {
            print "  mkdir $fname\n";
            mkpath($fname);
        }
    }

    system($^X, 'Makefile.PL') == 0 or die;
    system 'make';
    system('make', 'test') == 0 or die;
    system 'git init';
    system 'git add .';
    system 'git commit -m "initial import"';
}

=pod

=head1 SYNOPSIS

    % webapp-starter.pl MyApp

=cut

__DATA__

@@ Makefile.PL
use inc::Module::Install;
name '<% name %>';
all_from 'lib/<% path %>.pm';

requires 'Text::Xslate' => 0.1047;
requires 'Text::Xslate::Bridge::TT2Like';
requires 'Mouse';
requires 'Log::Dispatch';
requires 'parent';
requires 'DBIx::Skinny';
requires 'DBD::SQLite';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More';
test_requires 'YAML';
test_requires 'Test::WWW::Mechanize::PSGI';
test_requires 'Test::Requires';
author_tests('xt');
auto_include;
WriteAll;

@@ .gitignore
Makefile
inc/
ppport.h
*.sw[po]
*.bak
*.old

@@ <% name %>.psgi
use strict;
use warnings;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use <% package %>::Web;
use Plack::Builder;

builder {
    enable 'Plack::Middleware::Static',
        path => qr{^/static/},
        root => './htdocs/';

    <% package %>::Web->to_app();
};

@@ lib/<% path %>.pm
package <% package %>;
use Mouse;
use <% path %>::ConfigLoader;
use Cwd ();
use <% package %>::DB;

our $VERSION = '0.01';

has config => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

my $root = do {
    my $p = __FILE__;
    $p = Cwd::abs_path($p) || $p;
    (my $q = __PACKAGE__) =~ s{::}{/}g;
    $p =~ s{$q\.pm$}{};
    $p =~ s{/lib/?$}{}g;
    $p =~ s{/blib/?$}{}g;
    $p;
};
sub root { $root }

sub context { die "cannot find context" }

sub bootstrap {
    my ($class) = @_;
    my $c = $class->new(config => <% package %>::ConfigLoader->load);
    no warnings 'redefine';
    *<% package %>::context = sub { $c };
    return $c;
}

has db => (
    is => 'ro',
    isa => '<% package %>::DB',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $conf = $self->config->{'DB'} || die "missing configuration for DB";
        <% package %>::DB->new($conf);
    },
);

no Mouse; __PACKAGE__->meta->make_immutable;

@@ lib/<% path %>/DB.pm
package <% package %>::DB;
use DBIx::Skinny;
1;

@@ lib/<% path %>/DB/Schema.pm
package <% package %>::DB::Schema;
use DBIx::Skinny::Schema;

# install_table user => schema {
#     pk 'id';
#     columns qw/
#     id
#     name
#     /;
# };

1;

@@ lib/<% path %>/Web.pm
package <% package %>::Web;
use Mouse;
use <% path %>;
use <% path %>::ConfigLoader;
use Text::Xslate 0.1047;
use Path::AttrRouter;
use Module::Find qw/useall/;
use Encode;
use Log::Dispatch;
use <% package %>::Web::C;
use HTTP::Session;
use HTTP::Session::State::Cookie;
use HTTP::Session::Store::DBM;
use File::Spec;
use <% package %>::Web::Response;
use <% package %>::Web::Request;

extends '<% package %>';

useall '<% path %>::Web';

has 'log' => (
    is      => 'ro',
    isa     => 'Log::Dispatch',
    lazy    => 1,
    default => sub {
        my $self = shift;
        Log::Dispatch->new( %{ $self->config->{'Log::Dispatch'} || {} } );
    },
);

has config => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

has env => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

has req => (
    is      => 'ro',
    isa     => 'Plack::Request',
    lazy    => 1,
    default => sub {
        my $self = shift;
        <% package %>::Web::Request->new( $self->env );
    }
);

has args => (
    is       => 'rw',
    isa      => 'ArrayRef',
);

has res => (
    is      => 'ro',
    isa     => 'Plack::Response',
    default => sub {
        <% package %>::Web::Response->new;
    },
);

has session => (
    is => 'ro',
    isa => 'HTTP::Session',
    lazy => 1,
    default => sub {
        my $self = shift;
        HTTP::Session->new(
            store => HTTP::Session::Store::DBM->new(
                file => File::Spec->catfile(File::Spec->tmpdir, "<% name %>.$<.dbm"),
            ),
            state => HTTP::Session::State::Cookie->new(
                name => '<% name %>_sid',
            ),
            request => $self->req,
        );
    },
);

sub request  { shift->req(@_) }
sub response { shift->res(@_) }

sub to_app {
    my ($class) = @_;

    my $config = <% package %>::ConfigLoader->load;
    sub {
        my $env = shift;
        my $c = $class->new(env => $env, config => $config);
        no warnings 'redefine';
        local *<% name %>::context = sub { $c };
        if (my $m = <% name %>::Web::C->router->match($env)) {
            $m->{code}->($c, $m);
            $c->session->response_filter($c->res);
            return $c->res->finalize;
        } else {
            my $content = 'not found';
            return [404, ['Content-Length' => length($content)], [$content]];
        }
    };
}

my $tx = Text::Xslate->new(
    syntax => 'TTerse',
    module => ['Text::Xslate::Bridge::TT2Like'],
    path   => [__PACKAGE__->root . "/tmpl"],
    function => {
        c => sub { NoPaste::context() },
        uri_for => sub {
            my ( $path, $args ) = @_;
            my $req = NoPaste::context()->req();
            my $uri = $req->base;
            $uri->path( do {
                my $p = $uri->path . $path;
                $p =~ s!//!!;
                $p;
            } );
            $uri->query_form(@$args) if $args;
            $uri;
        },
    },
);
sub render {
    my ($self, @args) = @_;
    my $body = $tx->render(@args);
    $self->res->status(200);
    $self->res->content_type('text/html; charset=utf-8');
    $self->res->body(encode_utf8($body));
}

no Mouse;__PACKAGE__->meta->make_immutable;

@@ lib/<% path %>/Web/Request.pm
package <% package %>::Web::Request;
use strict;
use warnings;
use parent qw/Plack::Request/;

1;

@@ lib/<% path %>/Web/Response.pm
package <% package %>::Web::Response;
use strict;
use warnings;
use parent qw/Plack::Response/;

sub not_found {
    my ($self) = @_;
    $self->status(404);
    $self->body('not found');
    $self;
}

1;

@@ lib/<% path %>/Web/C.pm
package <% package %>::Web::C;
use strict;
use warnings;
use Router::Simple::Sinatraish;

get '/' => sub {
    my ($c) = @_;
    $c->render('index.tx');
};

get '/counter' => sub {
    my ($c) = @_;
    $c->session->set('counter' => ($c->session->get('counter')||0)+1);
    $c->res->status(200);
    $c->res->body($c->session->session_id . ':' . $c->session->get('counter'));
};

1;

@@ lib/<% path %>/ConfigLoader.pm
package <% path %>::ConfigLoader;
use strict;
use warnings;
use File::Spec;
use Cwd ();
use <% package %>;

sub load {
    my $class = shift;
    my $env = $ENV{PLACK_ENV} || 'development';
    my $fname = File::Spec->catfile(<% package %>->root(), 'config', "${env}.pl");
    my $conf = do $fname or die "Cannot load configuration file: $fname";
    return $conf;
}

1;

@@ tmpl/
@@ tmpl/index.tx
[% INCLUDE 'include/header.tt' %]

[% INCLUDE 'include/footer.tt' %]
@@ tmpl/include/header.tt
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8" />
    <title><% name %></title>
    <meta http-equiv="Content-Style-Type" content="text/css" />  
    <meta http-equiv="Content-Script-Type" content="text/javascript" />  
    <link href="/static/css/app.css" rel="stylesheet" type="text/css" media="screen" />
</head>
<body id="[% IF bodyID %][% bodyID %][% ELSE %]Default[% END %]">
    <div id="Container">
        <div id="Header">
            <a href="/"><% name %></a>
        </div>
        <div id="Content">
@@ tmpl/include/footer.tt
        </div>
        <div class="clear-both"></div>
    </div>
</body>
</html>
@@ sql/
@@ t/

@@ t/Util.pm
package t::Util;
use strict;
use warnings;
use parent qw/Exporter/;
1;

@@ t/02_mech.t
use strict;
use warnings;
use Plack::Test;
use Plack::Util;
use Test::More;
use Test::Requires 'Test::WWW::Mechanize::PSGI';
use t::Util;

my $app = Plack::Util::load_psgi '<% name %>.psgi';

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);
$mech->get_ok('/');

done_testing;

@@ t/03_session.t
use strict;
use warnings;
use Plack::Test;
use Plack::Util;
use Test::More;
use Test::WWW::Mechanize::PSGI;
use t::Util;

my $app = Plack::Util::load_psgi '<% name %>.psgi';

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);
$mech->get_ok('/counter');
my ($sid1, $cnt1) = split /:/, $mech->content;
is $cnt1, 1;
$mech->get_ok('/counter');
my ($sid2, $cnt2) = split /:/, $mech->content;
is $sid1, $sid2;
is $cnt2, 2;
$mech->get_ok('/counter');
my ($sid3, $cnt3) = split /:/, $mech->content;
is $sid1, $sid3;
is $cnt3, 3;

done_testing;

@@ xt/
@@ htdocs/
@@ htdocs/static/img/
@@ htdocs/static/js/
@@ htdocs/static/css/app.css
/* place holder */

@@ script/dummy.pl
use strict;
use warnings;
use <% package %>;

my $c = <% package %>->bootstrap;

...

@@ config/development.pl
+{
    'Log::Dispatch' => {
        outputs => [
            [ 'Screen', min_level => 'warning' ],
        ]
    },
    DB => {
        dsn      => 'dbi:SQLite:',
        username => '',
        password => '',
        connect_options => +{
            sqlite_unicode => 1,
          # 'mysql_enable_utf8' => 1,
          # 'mysql_read_default_file' => '/etc/mysql/my.cnf',
        },
    },
}
@@ config/production.pl
+{
}

