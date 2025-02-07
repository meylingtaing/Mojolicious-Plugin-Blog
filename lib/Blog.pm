package Blog;

use strict;
use warnings;

use DBI;
use Date::Format;
use Date::Parse;
use File::Slurp qw(read_file);
use Carp qw(croak);

=head1 NAME

Blog

=head1 SYNOPSIS

=head1 METHODS

=cut

sub new {
    my $class = shift;

    my $dbh = DBI->connect("DBI:SQLite:dbname=" . shift,
        undef, # username
        undef, # password
        { RaiseError => 1 }
    ) or die $DBI::errstr;

    $dbh->{sqlite_unicode} = 1;

    my $self = { dbh => $dbh };
    bless $self, $class;
    return $self;
}

=head2 get_tags

=cut

sub get_tags {
    my ($self) = @_;
    my @rows = $self->{dbh}->selectall_array("select label from Tags");
    return map { $_->[0] } @rows;
}

=head2 get_all_entry_metadata

Returns a list of hashes with these fields:

    id
    title
    year

=cut

sub get_all_entry_metadata {
    my ($self) = @_;

    my @rows = $self->_get_entries(
        skip_content => 1,
    );
    for my $row (@rows) {
        delete $row->{temp_file};

        my $datetime = str2time(delete $row->{time_stamp});
        $row->{year} = time2str("%Y", $datetime);
    }

    return @rows;
}

=head2 get_entries

Params: C<$page> (optional, defaults to 0), C<$sort>

Returns an arrayref of hashrefs, each hashref with these fields:

    id
    title
    content
    date
    time
    tags

=cut

sub get_entries {
    my ($self, %params) = @_;
    my $page = $params{page} || 0;
    my $sort = $params{sort} || "backwards";
    my $tag  = $params{tag};

    my $show_hidden = $params{show_hidden};

    my @rows = $self->_get_entries(
        page  => $page,
        sort  => $sort,
        limit => 5,
        $tag ? (tag => $tag) : (),
        $show_hidden ? () : (where => 'hidden = 0'),
    );

    $self->_modify_entry_hash_for_view($_) for @rows;

    return \@rows;
}

=head2 get_next_entry_metadata

=cut

sub get_next_entry_metadata {
    my ($self, %params) = @_;

    my $id        = $params{id};
    my $timestamp = $params{timestamp};

    my $sql = qq{
        select Updates.id, title
        from Updates
        where time_stamp < ?
        order by time_stamp desc limit 1
    };

    my @rows = $self->{dbh}->selectall_array($sql, { Slice => {} }, $timestamp);
    return $rows[0];
}

=head2 get_prev_entry_metadata

=cut

sub get_prev_entry_metadata {
    my ($self, %params) = @_;

    my $id        = $params{id};
    my $timestamp = $params{timestamp};

    my $sql = qq{
        select Updates.id, title
        from Updates
        where time_stamp > ?
        order by time_stamp asc limit 1
    };

    my @rows = $self->{dbh}->selectall_array($sql, { Slice => {} }, $timestamp);
    return $rows[0];
}

=head2 search

=cut

sub search {
    my ($self, $search) = @_;

    my @rows = $self->_get_entries(
        search       => $search,
        skip_content => 1,
    );
    return \@rows;
}

=head2 get_entries_for_rss

Returns an arrayref of hashrefs, each hashref with these fields:

    id
    title
    content
    datetime

=cut

sub get_entries_for_rss {
    my $self = shift;

    my @rows = $self->_get_entries(
        time_stamp_col => "datetime(time_stamp, 'utc') time_stamp",
        limit          => 5,
    );

    for my $row (@rows) {
        my $datetime = str2time(delete $row->{time_stamp});
        $row->{datetime} = time2str("%a, %d %b %Y %T +0000", $datetime);
    }

    return \@rows;
}

sub _get_entries {
    my ($self, %params) = @_;

    my $page   = $params{page} || 0;
    my $sort   = $params{sort} || "backwards";
    my $limit  = $params{limit};
    my $where  = $params{where} || '';
    my $tag    = $params{tag};
    my $search = $params{search};

    my $content = $params{skip_content} ? '' : 'content,';

    my $time_stamp_col = $params{time_stamp_col} || "time_stamp";

    my $order_clause = "order by time_stamp " .
        ($sort eq 'forwards' ? 'asc' : 'desc');

    my $limit_clause  = $limit ? "limit " . ($limit + 1) : '';

    my $where_clause = $where ? "and $where " : "";

    my @binds;
    my $sql = "select Updates.id, $time_stamp_col, $content temp_file, title " .
              "from Updates ";

    if ($tag) {
        $where_clause .= "and label = ? " if $tag;
        push @binds, $tag;
        $sql .= "join UpdateTags on Updates.id = UpdateTags.update_id " .
                "join Tags on Tags.id = UpdateTags.tag_id ";
    }

    if ($search) {
        $where_clause .= "and (content like ? or title like ?)";
        push @binds, "%$search%", "%$search%";
    }


    if ($page) {
        $limit_clause .= " offset ?" if $page;
        push @binds, $page * 5;
    }

    $sql .= "where (temp_file is not null or published = 1) " .
            "$where_clause " .
            "$order_clause $limit_clause";

    # Fetch updates from the database
    my @rows = $self->{dbh}->selectall_array($sql,
        { Slice => {} }, @binds
    );

    return @rows;
}

=head2 get_entry

Params: $id (required)

Returns a hashref as defined in L</get_entries>.

=cut

sub get_entry {
    my $self = shift;
    my $id = shift;

    croak "Called get_entry without a valid id!" unless $id;

    # XXX Maybe do something if an invalid entry is selected
    my $entry = $self->{dbh}->selectall_arrayref(
        "select id, time_stamp, content, temp_file, title from Updates " .
        "where id = ? and (temp_file is not null or published = 1)",
        { Slice => {} }, $id
    )->[0];

    $self->_modify_entry_hash_for_view($entry);

    return $entry;
}

=head1 INTERNALS

=cut

sub _modify_entry_hash_for_view {
    my $self = shift;
    my $row = shift;

    my $datetime = str2time($row->{time_stamp});

    $row->{date} = time2str("%B %e, %Y", $datetime);
    $row->{time} = time2str("%l:%M %p", $datetime);

    # Check if there is a temp file set...if so get the content from that
    if (my $temp_file = delete $row->{temp_file}) {
        $row->{content} = read_file($temp_file, binmode => 'utf8');
    }

    # Also get the tags
    my @tags = map { $_->[0] } $self->{dbh}->selectall_array(
        "select label from UpdateTags " .
        "join Tags on tag_id = Tags.id " .
        "where update_id = ?",
        undef, $row->{id}
    );
    $row->{tags} = \@tags;

    return $row;
}

1;
