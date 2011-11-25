package Treex::Tool::Parallel::MessageBoard;

use Moose;
use Treex::Core::Common;
use File::Temp qw(tempdir);
use Cwd 'abs_path';
use Storable;

has path => (
    is => 'rw',
    isa => 'Str',
    default => '.',
    documentation => 'directory in which working directory structure will be created',
);

has workdir => (
    is => 'rw',
    isa => 'Str',
    documentation => 'working directory created for storing messages',
);

has sharers => (
    is => 'rw',
    isa => 'Int',
    documentation => 'total number of talking and/or listening participants',
);

has current => (
    is => 'rw',
    isa => 'Int',
    documentation => 'the number representing the current participant (1 <= current <= sharers)',
);

has message_counter => (
    is => 'rw',
    isa => 'Int',
    default => 0,
    documentation => 'number of written messages',
);

sub BUILD {
    my ( $self ) = @_;

    if ( $self->current and $self->current > $self->sharers ) {
        log_fatal 'Number of the current participant cannnot be higher than the total number of participants';
    }

    if ( not $self->workdir ) {
        my $counter;
        my $directory_prefix;
        my @existing_dirs;

        # search for the first unoccupied directory prefix
        do {
            $counter++;
            $directory_prefix = sprintf $self->path."/%03d_message_board_", $counter;
            @existing_dirs = glob "$directory_prefix*";
        }
            while (@existing_dirs);

        my $directory = tempdir "${directory_prefix}XXXXX" or log_fatal($!);
        $self->set_workdir($directory);

        foreach my $sharer (1..$self->sharers) {
            mkdir $self->_dir_for_writing($sharer) or log_fatal $!;
            mkdir $self->_dir_for_reading($sharer) or log_fatal $!;
        }
        log_info "Working directory $directory created";
    }
}

sub _dir_for_writing {
    my $self = shift;
    my $sharer_number = shift || $self->current;
    return $self->workdir."/from".sprintf("%03d",$sharer_number);
}

sub _dir_for_reading {
    my $self = shift;
    my $sharer_number = shift || $self->current;
    return $self->workdir."/for".sprintf("%03d",$sharer_number);
}

sub write_message {
    my ( $self, $message ) = @_;

    $self->set_message_counter( $self->message_counter + 1 );
    my $base_name = "msg".sprintf("%06d",$self->message_counter)."_from".sprintf("%03d",$self->current).".pls";
    my $message_file_name = $self->_dir_for_writing."/".$base_name;

    Storable::nstore( $message, $message_file_name );
    foreach my $addressee (grep {$_ ne $self->current} (1..$self->sharers)) {
        symlink $message_file_name, $self->_dir_for_reading($addressee)."/$base_name" or die $!;
    }

    return 1;
}

sub read_message {
    my ( $self ) = @_;
    my $message;

    if ( my ($file_to_read) = glob $self->_dir_for_reading."/*.pls" ) {
        $message = Storable::retrieve( readlink $file_to_read ) or die $!;
        unlink $file_to_read;
    }

    return $message;
}

sub read_messages {
    my ( $self ) = @_;
    my @messages;
    while ( my $message = $self->read_message ) {
        push @messages, $message;
    }
    return @messages;
}

1;
