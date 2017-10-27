package Debian::Debhelper::Buildsystem::golang;

=head1 NAME

dh-golang -- debhelper build system class for Go packages

=head1 DESCRIPTION

The dh-golang package provides a build system for debhelper which can be used in
the following way:

 %:
 	dh $@ --buildsystem=golang --with=golang

=head1 IMPLEMENTATION

Here is a brief description of how the golang build system implements each
debhelper build system stage:

=over

=item B<configure>

Creates a Go workspace (see https://golang.org/doc/code.html#Workspaces) in the
build directory. Copies the source code into that workspace and symlinks all
available libraries from /usr/share/gocode/src into the workspace because the
go(1) tool requires write access to the workspace. See also
C<DH_GOLANG_INSTALL_EXTRA> and C<DH_GOLANG_INSTALL_ALL>.

=item B<build>

Determines build targets (see also C<DH_GOLANG_BUILDPKG> and
C<DH_GOLANG_EXCLUDES>), possibly calls C<go generate> (see also
C<DH_GOLANG_GO_GENERATE>), then calls C<go install>.

=item B<test>

Calls C<go test -v> on all build targets.

=item B<install>

Installs binaries and sources from the build directory into the Debian package
destdir. See also C<--no-source> and C<--no-binaries>.

=item B<clean>

Removes the build directory.

=back

=head1 OPTIONS

=over

=item B<dh_auto_install>

=over

=item B<--no-source>

By default, all files within the src/ subdirectory of the build directory will
be copied to /usr/share/gocode/src/ of the Debian package destdir. Specifying
the C<--no-source> option disables this behavior, which is useful if you are
packaging a program (as opposed to a library).

Example (in C<debian/rules>):

 override_dh_auto_install:
 	dh_auto_install -- --no-source

=item B<--no-binaries>

By default, all files within the bin/ subdirectory of the build directory will
be copied to /usr/bin/ of the Debian package destdir. Specifying the
C<--no-binaries> option disables this behavior.

Example (in C<debian/rules>):

 override_dh_auto_install:
 	dh_auto_install -- --no-binaries

Note: instead of using this option (which was added for symmetry with
C<--no-source>), consider not building unwanted binaries in the first place to
save CPU time on our build daemons; see C<DH_GOLANG_EXCLUDES>.

=back

=back

=head1 ENVIRONMENT VARIABLES

=over

=item C<DH_GOPKG>

C<DH_GOPKG> (string) contains the Go package name which this Debian package is
building.

C<DH_GOPKG> is automatically set to the value of the C<XS-Go-Import-Path>
C<debian/control> field.

Example (in C<debian/control>):

 XS-Go-Import-Path: github.com/debian/ratt

Historical note: before the C<XS-Go-Import-Path> field was introduced, we used
to set C<DH_GOPKG> in C<debian/rules>. When you encounter such a package, please
convert it by moving the value from C<debian/rules> to C<debian/control>. It is
preferable to use the C<debian/control> field because it is machine-readable and
picked up/used by various Debian infrastructure tools, whereas C<debian/rules> is
very hard to parse.

=item DH_GOLANG_INSTALL_EXTRA

C<DH_GOLANG_INSTALL_EXTRA> (list of strings, whitespace-separated, default
empty) enumerates files and directories which are additionally installed into
the build directory. By default, only files with the following extension are
installed: .go, .c, .cc, .h, .hh, .proto, .s.

Example (in C<debian/rules>):

 export DH_GOLANG_INSTALL_EXTRA := html/charset/testdata html/testdata \
    bpf/testdata

=item DH_GOLANG_INSTALL_ALL

C<DH_GOLANG_INSTALL_ALL> (bool, default false) controls whether all files are
installed into the build directory. By default, only files with the following
extension are installed: .go, .c, .cc, .h, .hh, .proto, .s.

Example (in C<debian/rules>):

 export DH_GOLANG_INSTALL_ALL := 1

Note: prefer the C<DH_GOLANG_INSTALL_EXTRA> environment variable because it is
self-documenting and future-proof: when using C<DH_GOLANG_INSTALL_ALL>, readers
of your package cannot easily tell which extra files in particular need to be
installed, and newer upstream versions might result in unexpected extra files.

=item DH_GOLANG_BUILDPKG

C<DH_GOLANG_BUILDPKG> (list of strings, whitespace-separated, default
C<${DH_GOPKG}/...>) defines the build targets for compiling this Go package. In
other words, this is what will be passed to C<go install>.

The default value matches all Go packages within the source, which is usually
desired, but you might need to exclude example programs, for which you should
use the C<DH_GOLANG_EXCLUDES> environment variable.

Example (in C<debian/rules>):

 # Install only programs for end users, the also-included Go packages are not
 # yet mature enough to be shipped for other packages to consume (despite what
 # upstream claims).
 export DH_GOLANG_BUILDPKG := github.com/debian/ratt/cmd/...

=item DH_GOLANG_EXCLUDES

C<DH_GOLANG_EXCLUDES> (list of Perl regular expressions, whitespace-separated,
default empty) defines regular expression patterns to exclude from the build
targets expanded from C<DH_GOLANG_BUILDPKG>.

Example (in C<debian/rules>):

 # We want to ship only the library packages themselves, not the accompanying
 # example binaries.
 export DH_GOLANG_EXCLUDES := examples/

=item DH_GOLANG_GO_GENERATE

C<DH_GOLANG_GO_GENERATE> (bool, default false) controls whether C<go generate>
is called on all build targets (see C<DH_GOLANG_BUILDPKG>).

It is convention in the Go community to commit all C<go generate> artifacts to
version control, so re-generating these artifacts is usually not required.

Depending on what the Go package in question uses C<go generate> for, you may
want to enable C<DH_GOLANG_GO_GENERATE>:

=over

=item *

If the Go package uses C<go generate> to generate artifacts purely from inputs
within its own source (e.g. creating a perfect hash table), there usually is no
need to re-generate that output. It does not necessarily hurt, either, but some
C<go generate> commands might be poorly tested and break the build.

=item *

If the Go package uses C<go generate> to (e.g.) bundle a JavaScript library into
a template file which is then compiled into a Go program, it is advisable to
re-generate that output so that the Debian version of the JavaScript library is
picked up, as opposed to the pre-generated version.

=back

Example (in C<debian/rules>):

 export DH_GOLANG_GO_GENERATE := 1

Note: this option should default to true, but it was introduced after dh-golang
was already widely used, and nobody made the transition happen yet (i.e. inspect
and possibly fix any resulting breakages).

=back

=cut

use strict;
use base 'Debian::Debhelper::Buildsystem';
use Debian::Debhelper::Dh_Lib;
use Dpkg::Control::Info;
use File::Copy; # in core since 5.002
use File::Path qw(make_path); # in core since 5.001
use File::Find; # in core since 5

sub DESCRIPTION {
    "Go"
}

sub check_auto_buildable {
    return 0
}

sub new {
    my $class = shift;
    my $this = $class->SUPER::new(@_);
    $this->prefer_out_of_source_building();
    _set_dh_gopkg();
    return $this;
}

sub _set_dh_gopkg {
    # If DH_GOPKG is missing, try to set it from the XS-Go-Import-Path field
    # from debian/control. If this approach works well, we will only use this
    # method in the future.
    return if defined($ENV{DH_GOPKG}) && $ENV{DH_GOPKG} ne '';

    my $control = Dpkg::Control::Info->new();
    my $source = $control->get_source();
    $ENV{DH_GOPKG} = $source->{"XS-Go-Import-Path"};
}

sub _set_gopath {
    my $this = shift;
    $ENV{GOPATH} = $this->{cwd} . '/' . $this->get_builddir();
}

sub _link_contents {
    my ($src, $dst) = @_;

    my @contents = glob "$src/*";
    # Safety-Check: We are already _in_ a Go library. Don’t copy its
    # subfolders, this has no use and potentially only screws things up.
    # This situation should never happen, unless some package ships files that
    # are already shipped in another package.
    my @gosrc = grep { /\.go$/ } @contents;
    return if @gosrc > 0;
    my @dirs = grep { -d } @contents;
    for my $dir (@dirs) {
        my $base = basename($dir);
        if (-d "$dst/$base") {
            if ( 0 <= index($dir, q{/usr/share/gocode/src/}.$ENV{DH_GOPKG}) ){
                warning( qq{"$ENV{DH_GOPKG}" is already installed. Please check for circular dependencies.\n} );
            }else{
                _link_contents("$src/$base", "$dst/$base");
            }
        } else {
            verbose_print("Symlink $src/$base -> $dst/$base");
            symlink("$src/$base", "$dst/$base");
        }
    }
}

sub configure {
    my $this = shift;

    $this->mkdir_builddir();

    my $builddir = $this->get_builddir();

    ############################################################################
    # Copy all source files into the build directory $builddir/src/$go_package
    ############################################################################

    my $install_all = (exists($ENV{DH_GOLANG_INSTALL_ALL}) &&
                       $ENV{DH_GOLANG_INSTALL_ALL} == 1);

    # By default, only files with the following extensions are installed:
    my %whitelisted_exts = (
        '.go' => 1,
        '.c' => 1,
        '.cc' => 1,
        '.h' => 1,
        '.hh' => 1,
        '.proto' => 1,
        '.s' => 1,
    );

    my @sourcefiles;
    find({
        # Ignores ./debian entirely, but not e.g. foo/debian/debian.go
        # Ignores ./.pc (quilt) entirely.
        # Also ignores the build directory to avoid recursive copies.
        preprocess => sub {
            return @_ if $File::Find::dir ne '.';
            return grep {
                $_ ne 'debian' &&
                $_ ne '.pc' &&
                $_ ne '.git' &&
                $_ ne $builddir
            } @_;
        },
        wanted => sub {
            # Strip “./” in the beginning of the path.
            my $name = substr($File::Find::name, 2);
            if ($install_all) {
                # All files will be installed
            } else {
                my $dot = rindex($name, ".");
                return if $dot == -1;
                return unless $whitelisted_exts{substr($name, $dot)};
            }
            return unless -f $name;
            push @sourcefiles, $name;
        },
        no_chdir => 1,
    }, '.');

    # Extra files/directories to install.
    my @install_extra = (exists($ENV{DH_GOLANG_INSTALL_EXTRA}) ?
                         split(/ /, $ENV{DH_GOLANG_INSTALL_EXTRA}) : ());

    find({
        wanted => sub {
            return unless -f $File::Find::name;
            push @sourcefiles, $File::Find::name;
        },
        no_chdir => 1,
    }, @install_extra) if(@install_extra);

    for my $source (@sourcefiles) {
        my $dest = "$builddir/src/$ENV{DH_GOPKG}/$source";
        make_path(dirname($dest));
        # Avoid re-copying the files, this would update their timestamp and
        # make go(1) recompile them.
        next if -f $dest;
        verbose_print("Copy $source -> $dest");
        copy($source, $dest) or error("Could not copy $source to $dest: $!");
    }

    ############################################################################
    # Symlink all available libraries from /usr/share/gocode/src into our
    # buildroot.
    ############################################################################

    # NB: The naïve idea of just setting GOPATH=$builddir:/usr/share/godoc does
    # not work. Let’s call the two paths in $GOPATH components. go(1), when
    # installing a package, such as github.com/Debian/dcs/cmd/..., will also
    # install the compiled dependencies, e.g. github.com/mstap/godebiancontrol.
    # When such a dependency is found in a component’s src/ directory, the
    # resulting files will be stored in the same component’s pkg/ directory.
    # That is, in this example, go(1) wants to modify
    # /usr/share/gocode/pkg/linux_amd64/github.com/mstap/godebiancontrol, which
    # will obviously not succeed due to permission errors.
    #
    # Therefore, we just work with a single component that is under our control
    # and symlink all the sources into that component ($builddir).

    _link_contents('/usr/share/gocode/src', "$builddir/src");
}

sub get_targets {
    my $buildpkg = $ENV{DH_GOLANG_BUILDPKG} || "$ENV{DH_GOPKG}/...";
    my $output = qx(go list $buildpkg);
    my @excludes = (exists($ENV{DH_GOLANG_EXCLUDES}) ?
                    split(/ /, $ENV{DH_GOLANG_EXCLUDES}) : ());
    my @targets = split(/\n/, $output);

    # Remove all targets that are matched by one of the regular expressions in DH_GOLANG_EXCLUDES.
    for my $pattern (@excludes) {
        @targets = grep { !/$pattern/ } @targets;
    }

    return @targets;
}

sub build {
    my $this = shift;

    $this->_set_gopath();
    if (exists($ENV{DH_GOLANG_GO_GENERATE}) && $ENV{DH_GOLANG_GO_GENERATE} == 1) {
        $this->doit_in_builddir("go", "generate", "-v", @_, get_targets());
    }
    unshift @_, ('-p', $this->get_parallel());
    my $trimpath = "\"-trimpath=" . $ENV{GOPATH} . "/src\"";
    $this->doit_in_builddir("go", "install", "-gcflags=$trimpath", "-asmflags=$trimpath", "-v", @_, get_targets());
}

sub test {
    my $this = shift;

    $this->_set_gopath();
    unshift @_, ('-p', $this->get_parallel());
    $this->doit_in_builddir("go", "test", "-v", @_, get_targets());
}

sub install {
    my $this = shift;
    my $destdir = shift;
    my $builddir = $this->get_builddir();
    my $install_source = 1;
    my $install_binaries = 1;

    while(@_) {
        if($_[0] eq '--no-source') {
            $install_source = 0;
            shift;
        } elsif($_[0] eq '--no-binaries') {
            $install_binaries = 0;
            shift;
        } else {
            error("Unknown option $_[0]");
        }
    }

    my @binaries = glob "$builddir/bin/*";
    if ($install_binaries and @binaries > 0) {
        $this->doit_in_builddir('mkdir', '-p', "$destdir/usr");
        $this->doit_in_builddir('cp', '-r', 'bin', "$destdir/usr");
    }

    if ($install_source) {
        # Path to the src/ directory within $destdir
        my $dest_src = "$destdir/usr/share/gocode/src/$ENV{DH_GOPKG}";
        $this->doit_in_builddir('mkdir', '-p', $dest_src);
        $this->doit_in_builddir('cp', '-r', '-T', "src/$ENV{DH_GOPKG}", $dest_src);
    }
}

sub clean {
    my $this = shift;

    $this->rmdir_builddir();
}

1
# vim:ts=4:sw=4:expandtab
