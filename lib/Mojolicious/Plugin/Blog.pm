package Mojolicious::Plugin::Blog;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::File qw(curfile);
use Path::Tiny;
use File::Share;

our $VERSION = '0.31';

sub register {
    my ($self, $app) = @_;
    push @{ $app->routes->namespaces }, 'Mojolicious::Plugin::Blog::Controller';

    my $share_dir = File::Share::dist_dir('Mojolicious-Plugin-Blog');
    push @{ $app->renderer->paths }, $share_dir . '/templates';
}

1;

=encoding utf8

=head1 WHAT IS THIS?

A while back, I wrote some code to help me write blog posts for my
various sites. I don't remember how it all works. Maybe I'll figure it
out again though.

See the notes.md file in the top level of the repo for more explanation

The rest of this documentation is regular POD stuff that was probably
copy-pasted or generated automatically?

=head1 NAME

Mojolicious::Plugin::Blog - Mojolicious Plugin

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('Blog');

  # Mojolicious::Lite
  plugin 'Blog';

=head1 DESCRIPTION

L<Mojolicious::Plugin::Blog> is a L<Mojolicious> plugin.

=head1 METHODS

L<Mojolicious::Plugin::Blog> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=head1 AUTHOR

Kirsten Taing E<lt> meylingtaing@gmail.com E<gt>

=cut
