package CPANMetaDB::Dist;
use strict;

my %dist;

sub new {
    my($class, $version, $distfile) = @_;
    bless { version => $version, distfile => $distfile }, $class;
}

sub lookup {
    my($class, $pkg) = @_;
    return $dist{$pkg} ? $class->new(@{$dist{$pkg}}) : undef;
}

sub update {
    my($class, $pkg, $data) = @_;
    return $dist{$pkg} = $data;
}

sub cleanup { %dist = () }

package CPANMetaDB::Dist::Updater;
use AnyEvent;
use AnyEvent::HTTP;
use File::Temp;
use IO::Uncompress::Gunzip;
use HTTP::Date ();

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->register;
    return $self;
}

sub register {
    my $self = shift;
    $self->{tmpdir} = File::Temp::tempdir;
    # $self->{modified} = HTTP::Date::time2str(time - 600);

    $self->{t} = AE::timer 0, 300, sub {
        $self->fetch_packages;
    };
}

sub fetch_packages {
    my $self = shift;

    my $mirror = "http://cpan.metacpan.org";
    my $url    = "$mirror/modules/02packages.details.txt.gz";

    my $time = time;
    my $file = "$self->{tmpdir}/02packages.details.$time.txt.gz";
    open my $fh, ">", $file;

    warn "----> Start downloading $url\n";

    AnyEvent::HTTP::http_get $url,
        headers => {
            $self->{modified} ? ('If-Modified-Since' => $self->{modified}) : (),
        },
        on_body => sub {
            my($data, $hdr) = @_;
            print $fh $data;
        },
        sub {
            my (undef, $hdr) = @_;
            close $fh;

            if ($hdr->{Status} == 200) {
                warn "----> Download complete!\n";
                $self->{modified} = $hdr->{'last-modified'};
                $self->update_packages($file);
            } elsif ($hdr->{Status} == 304) {
                warn "----> Not modified since $self->{modified}\n";
            } else {
                warn "!!! Error: $hdr->{Status}\n";
            }
        };
}

sub update_packages {
    my($self, $file) = @_;

    warn "----> Extracting packages from $file\n";
    my $z = IO::Uncompress::Gunzip->new($file);

    my $in_body;
    my $count = 0;
    CPANMetaDB::Dist->cleanup();
    while (<$z>) {
        chomp;
        /^Last-Updated: (.*)/
            and warn "----> Last updated $1\n";
        if (/^$/) {
            $in_body = 1;
            next;
        } elsif ($in_body) {
            $count++;
            my($pkg, $version, $path) = split /\s+/, $_, 3;
            CPANMetaDB::Dist->update($pkg, [ $version, $path ]);
        }
    }

    warn "----> Complete! Updated $count packages\n";

    unlink $file;
}

1;
