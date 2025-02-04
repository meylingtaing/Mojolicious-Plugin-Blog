use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Mojolicious::Plugin::Blog',
    VERSION_FROM => 'lib/Mojolicious/Plugin/Blog.pm',
    EXE_FILES    => ['bin/mojo-blog'],
);
