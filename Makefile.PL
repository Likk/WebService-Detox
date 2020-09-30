use inc::Module::Install;
name 'WebService-Detox';
all_from 'lib/WebService/Detox.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
