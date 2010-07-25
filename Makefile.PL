use inc::Module::Install;
name 'App-WebAppStarter';
all_from 'lib/App/WebAppStarter.pm';

requires 'Text::Xslate' => 0.1047;
requires 'Router::Simple' => 0.06;
requires 'Data::Section::Simple';
requires 'Text::Xslate::Bridge::TT2Like' => 0.00003;
requires 'DBIx::Skinny';
requires 'Module::Install::AuthorTests';
requires 'HTTP::Session' => 0.40;

readme_markdown_from 'lib/App/WebAppStarter.pm';
tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More';
test_requires 'YAML';
author_tests('xt');
# use_test_base;
auto_include;
WriteAll;
