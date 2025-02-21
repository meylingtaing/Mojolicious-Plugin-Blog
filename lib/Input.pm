package Input;

use strict;
use warnings;

use File::Temp qw(tempfile);
use open ':encoding(UTF-8)';

=head2 via_editor

This opens up vim to edit the text

=cut

sub via_editor {
    my ($content, $filename) = @_;
    my $fh;

    # Make a temporary file if we didn't get one
    if ($filename) {
        open($fh, ">", $filename)
            or die "Cannot open $filename for writing: $!";
    }
    else {
        ($fh, $filename) = tempfile("update-XXXX",
            DIR    => 'tmp',
            SUFFIX => '.txt',
        );
    }

    print $fh $content;
    close $fh;

    # Open up vim on that file
    system('vim', $filename);

    # Once vim is closed, read the contents of the file
    open($fh, "<", $filename) or die "Cannot read $filename: $!";
    $content = do { local $/; <$fh> };

    unlink $filename;

    return $content;
}

=head2 from_prompt

Displays the given string, which should prompt the user for input. This returns
the user's input

=cut

sub from_prompt {
    my $prompt = shift;
    print "$prompt ";
    my $input = <STDIN>;
    chomp $input;
    return $input;
}

=head2 confirm

Asks the user for a yes/no response. This returns true if whatever the user
entered starts with a 'y'

=cut

sub confirm {
    print "Is this okay? ";
    my $yesno = <STDIN>;
    chomp $yesno;
    return 1 if substr($yesno, 0, 1) eq 'y';
    return 0;
}

1;
