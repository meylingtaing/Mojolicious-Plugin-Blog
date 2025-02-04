package Mojolicious::Plugin::Blog::Controller::Blog;
use Mojo::Base 'Mojolicious::Controller';

use Blog;
use Text::MultiMarkdown qw(markdown);

=head1 ROUTES

=head2 blog

Expects C<page>, C<db>, and C<template> to be stashed.

Optionally, you can also include C<tag> and/or C<direction>.

=cut

sub blog {
    my $c = shift;
    $c->_stash_blog_entries($c->stash('db'));
    $c->render(template => $c->stash('template'));
}

=head2 blog_entry

Expects C<id>, C<db>, and C<template> in the stash.

=cut

sub blog_entry {
    my $c = shift;

    my $id = $c->stash('id');
    my $blog = Blog->new($c->stash('db'));
    my $update = $blog->get_entry($id);

    ($update->{content}) = $c->_enhance_content($update->{content});

    my $next_entry = $blog->get_next_entry_metadata(
        id => $update->{id},
        timestamp => $update->{time_stamp}
    );
    my $prev_entry = $blog->get_prev_entry_metadata(
        id => $update->{id},
        timestamp => $update->{time_stamp}
    );

    $c->stash(next_entry => $next_entry);
    $c->stash(prev_entry => $prev_entry);

    $c->stash(update => $update);
    $c->render(template => $c->stash('template'));
}

=head2 search

Expects C<template> in the stash. Reads the query param C<search>.

=cut

sub search {
    my $c = shift;

    my $search = $c->param('search') // '';
    my $updates = [];
    if ($search) {
        my $blog = Blog->new($c->stash('db'));
        $updates = $blog->search($search);

    }
    $c->stash(search => $search);
    $c->stash(updates => $updates);
    $c->render(template => $c->stash('template'));
}

=head2 rss

=cut

sub rss {
    my $c = shift;

    my $blog = Blog->new($c->stash('db'));
    my $updates = $blog->get_entries_for_rss;

    ($_->{content}) = $c->_enhance_content($_->{content}, rss => 1)
        for @$updates;

    $c->stash(updates => $updates);
    $c->render(format => 'rss', template => 'rss');
}

=head1 INTERNALS

=head2 _stash_blog_entries

Expects a C<page> to be in the stash. C<direction> can optionally be in the
stash. C<tag> can also optionally be in the stash.

By default, this won't show hidden entries. C<show_hidden> will show the
hidden entries.

Gets blog entries and stashes these fields:

    prev
    next
    updates

=cut

sub _stash_blog_entries {
    my $c  = shift;
    my $db = shift;

    my $truncate = $c->stash('truncate');

    # XXX What if we're given an invalid page?
    my $page = $c->stash('page');
    $page = 0 unless $page =~ /^\d+$/;

    # Need to convert the markdown to html
    my $blog = Blog->new($db);
    my $updates = $blog->get_entries(
        page        => $page,
        sort        => $c->stash('direction'),
        tag         => $c->stash('tag'),
        show_hidden => $c->stash('show_hidden'),
    );
    for (@$updates) {
        my $truncated;
        ($_->{content}, $truncated) =
            $c->_enhance_content($_->{content}, truncate => $truncate);
        $_->{truncated} = 1 if $truncated;
    }

    # See if we should add More Recent and Older
    $c->stash(prev => ($page > 0) ? ($page - 1) : undef);
    $c->stash(next => undef);

    if (scalar @$updates > 5) {
        $c->stash(next => ($page + 1));
        pop @$updates;
    }

    $c->stash(updates => $updates);
};

sub _enhance_content {
    my ($c, $content, %params) = @_;
    my $truncate = $params{truncate};
    my $rss      = $params{rss};
    my $truncated;

    # XXX: Make it so the links open up in a new tab

    if ($truncate) {
        ($content, $truncated) = split /<pagebreak>/, $content;
    }
    else {
        $content =~ s/<pagebreak>\n//g;
    }

    # Look for <image $url> and convert that to special link
    $content =~
        s/<image (.*?)>(.*?)<\/image>
        /<a href="$1" class='show-image' markdown='1'>$2<\/a>/mxgs;

    # Look for <ascii-art> and convert that to proper div.
    if ($rss) {
        $content =~ s/<ascii-art>(.*?)<\/ascii-art>//mxgs;
    }
    else {
        $content =~
            s/<ascii-art>(.*?)<\/ascii-art>
             /<div class='center'>
             <pre><div class='ascii-art' markdown='1'>$1<\/div><\/pre>
             <\/div>/mxgs;
    }

    # Wrap code blocks in a div
    $content =~
        s/<code>(.*?)<\/code>
         /<pre><div class='code' markdown='1'><code>$1<\/code><\/div><\/pre>/mxgs;

    $content = markdown($content, { img_ids => 0 });

    # Add captions to images. This'll be...hack-y
    my $subs = ($content =~
        s/<p>(<img\ src=.*?)<\/p>\n\n   # Look for img tag
          <p>\^\ (.*?)<\/p>             # with the next section starting with ^
         /<figure>$1<figcaption><em>$2<\/em><\/figcaption><\/figure><p><\/p>
         /mgx);

    return ($content, $truncated);
}

1;
