use inc::Module::Install;
name 'App-WebAppStarter';
all_from 'lib/App/WebAppStarter.pm';

# requires '';


readme_markdown_from 'lib/App/WebAppStarter.pm';
tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Test::More';
test_requires 'YAML';
author_tests('xt');
# use_test_base;
auto_include;
WriteAll;
