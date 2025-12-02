package Session::Cookies;
use strict;
use warnings;
use JSON::PP ();

# Cookie management module for chrome-driver
# Get, set, clear, save, and load cookies

sub new {
    my ($class, %opts) = @_;

    my $chrome = $opts{chrome} or die "chrome parameter required";

    return bless {
        chrome  => $chrome,
        error   => undef,
    }, $class;
}

# Get all cookies for the current page
sub get_all {
    my ($self) = @_;

    my $result = $self->{chrome}->send('Network.getAllCookies');

    unless ($result && $result->{cookies}) {
        $self->{error} = $self->{chrome}->error() // "Failed to get cookies";
        return ();
    }

    return @{$result->{cookies}};
}

# Get cookies for a specific URL
sub get {
    my ($self, %opts) = @_;

    my %params;
    if ($opts{urls}) {
        $params{urls} = ref $opts{urls} ? $opts{urls} : [$opts{urls}];
    }

    my $result = $self->{chrome}->send('Network.getCookies', \%params);

    unless ($result && $result->{cookies}) {
        $self->{error} = $self->{chrome}->error() // "Failed to get cookies";
        return ();
    }

    return @{$result->{cookies}};
}

# Get a single cookie by name
sub get_cookie {
    my ($self, $name, %opts) = @_;

    my @cookies = $self->get(%opts);

    for my $cookie (@cookies) {
        if ($cookie->{name} eq $name) {
            return $cookie;
        }
    }

    return undef;
}

# Set a cookie
sub set {
    my ($self, %opts) = @_;

    # Required parameters
    unless ($opts{name} && defined $opts{value}) {
        $self->{error} = "name and value are required";
        return 0;
    }

    my %params = (
        name  => $opts{name},
        value => $opts{value},
    );

    # Optional parameters
    $params{url}            = $opts{url}      if defined $opts{url};
    $params{domain}         = $opts{domain}   if defined $opts{domain};
    $params{path}           = $opts{path}     if defined $opts{path};
    $params{secure}         = $opts{secure} ? \1 : \0 if defined $opts{secure};
    $params{httpOnly}       = $opts{http_only} ? \1 : \0 if defined $opts{http_only};
    $params{sameSite}       = $opts{same_site} if defined $opts{same_site};
    $params{expires}        = $opts{expires}  if defined $opts{expires};
    $params{priority}       = $opts{priority} if defined $opts{priority};
    $params{sameParty}      = $opts{same_party} ? \1 : \0 if defined $opts{same_party};

    my $result = $self->{chrome}->send('Network.setCookie', \%params);

    unless ($result && $result->{success}) {
        $self->{error} = $self->{chrome}->error() // "Failed to set cookie";
        return 0;
    }

    return 1;
}

# Delete a specific cookie
sub delete {
    my ($self, $name, %opts) = @_;

    my %params = (name => $name);

    $params{url}    = $opts{url}    if defined $opts{url};
    $params{domain} = $opts{domain} if defined $opts{domain};
    $params{path}   = $opts{path}   if defined $opts{path};

    my $result = $self->{chrome}->send('Network.deleteCookies', \%params);

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error() // "Failed to delete cookie";
        return 0;
    }

    return 1;
}

# Clear all cookies
sub clear {
    my ($self) = @_;

    my $result = $self->{chrome}->send('Network.clearBrowserCookies');

    unless (defined $result) {
        $self->{error} = $self->{chrome}->error() // "Failed to clear cookies";
        return 0;
    }

    return 1;
}

# Save cookies to a file
sub save {
    my ($self, $file) = @_;

    my @cookies = $self->get_all();

    unless (open(my $fh, '>', $file)) {
        $self->{error} = "Failed to open file for writing: $!";
        return 0;
    }

    my $json = JSON::PP->new->pretty->encode(\@cookies);

    if (open(my $fh, '>', $file)) {
        print $fh $json;
        close($fh);
        return 1;
    }

    $self->{error} = "Failed to write file: $!";
    return 0;
}

# Load cookies from a file
sub load {
    my ($self, $file) = @_;

    unless (-f $file) {
        $self->{error} = "File not found: $file";
        return 0;
    }

    my $content;
    if (open(my $fh, '<', $file)) {
        local $/;
        $content = <$fh>;
        close($fh);
    }
    else {
        $self->{error} = "Failed to open file: $!";
        return 0;
    }

    my $cookies;
    eval {
        $cookies = JSON::PP->new->decode($content);
    };

    if ($@ || ref $cookies ne 'ARRAY') {
        $self->{error} = "Invalid cookie file format";
        return 0;
    }

    # Set each cookie
    my $success = 0;
    for my $cookie (@$cookies) {
        if ($self->_set_from_saved($cookie)) {
            $success++;
        }
    }

    return $success;
}

# Set cookies from a saved format
sub _set_from_saved {
    my ($self, $cookie) = @_;

    my %params = (
        name  => $cookie->{name},
        value => $cookie->{value},
    );

    # Map saved cookie properties to setCookie params
    $params{domain}   = $cookie->{domain}   if $cookie->{domain};
    $params{path}     = $cookie->{path}     if $cookie->{path};
    $params{secure}   = $cookie->{secure} ? \1 : \0;
    $params{httpOnly} = $cookie->{httpOnly} ? \1 : \0;
    $params{sameSite} = $cookie->{sameSite} if $cookie->{sameSite};
    $params{expires}  = $cookie->{expires}  if $cookie->{expires};

    my $result = $self->{chrome}->send('Network.setCookie', \%params);

    return $result && $result->{success};
}

# Get cookies as HTTP header string
sub to_header {
    my ($self, %opts) = @_;

    my @cookies = $self->get(%opts);

    my @pairs;
    for my $cookie (@cookies) {
        push @pairs, "$cookie->{name}=$cookie->{value}";
    }

    return join('; ', @pairs);
}

# Set cookies from HTTP header string
sub from_header {
    my ($self, $header, %opts) = @_;

    my $url = $opts{url};

    # Parse Set-Cookie header
    my @parts = split /;\s*/, $header;
    return 0 unless @parts;

    # First part is name=value
    my ($name_value, @attrs) = @parts;
    my ($name, $value) = split /=/, $name_value, 2;

    return 0 unless defined $name && defined $value;

    my %cookie = (
        name  => $name,
        value => $value,
    );

    # Parse attributes
    for my $attr (@attrs) {
        my ($key, $val) = split /=/, $attr, 2;
        $key = lc($key);

        if ($key eq 'domain') {
            $cookie{domain} = $val;
        }
        elsif ($key eq 'path') {
            $cookie{path} = $val;
        }
        elsif ($key eq 'expires') {
            # Convert date string to epoch
            # This is a simplified conversion
            $cookie{expires} = $val;
        }
        elsif ($key eq 'max-age') {
            $cookie{expires} = time() + $val;
        }
        elsif ($key eq 'secure') {
            $cookie{secure} = 1;
        }
        elsif ($key eq 'httponly') {
            $cookie{http_only} = 1;
        }
        elsif ($key eq 'samesite') {
            $cookie{same_site} = ucfirst(lc($val));
        }
    }

    $cookie{url} = $url if $url;

    return $self->set(%cookie);
}

# Get last error
sub error {
    my ($self) = @_;
    return $self->{error};
}

1;

__END__

=head1 NAME

Session::Cookies - Cookie management for chrome-driver

=head1 SYNOPSIS

    use Session::Cookies;

    my $cookies = Session::Cookies->new(chrome => $chrome);

    # Get all cookies
    my @all = $cookies->get_all();

    # Get cookies for specific URLs
    my @site = $cookies->get(urls => 'https://example.com');

    # Get a specific cookie
    my $session = $cookies->get_cookie('session_id');

    # Set a cookie
    $cookies->set(
        name     => 'auth_token',
        value    => 'abc123',
        domain   => 'example.com',
        path     => '/',
        secure   => 1,
        http_only => 1,
        expires  => time() + 86400,
    );

    # Delete a cookie
    $cookies->delete('auth_token', domain => 'example.com');

    # Clear all cookies
    $cookies->clear();

    # Save cookies to file
    $cookies->save('/tmp/cookies.json');

    # Load cookies from file
    $cookies->load('/tmp/cookies.json');

=head1 DESCRIPTION

Session::Cookies provides cookie management for the chrome-driver plugin.
It uses Chrome's Network domain for cookie operations.

=head1 METHODS

=head2 new(%options)

Create a new Session::Cookies instance.

Options:
  - chrome: ChromeDriver instance (required)

=head2 get_all()

Get all cookies from the browser.

=head2 get(%options)

Get cookies, optionally filtered by URL.

Options:
  - urls: Single URL or array of URLs to filter by

=head2 get_cookie($name, %options)

Get a single cookie by name.

=head2 set(%options)

Set a cookie.

Options:
  - name: Cookie name (required)
  - value: Cookie value (required)
  - url: URL for the cookie
  - domain: Cookie domain
  - path: Cookie path
  - secure: Secure flag
  - http_only: HttpOnly flag
  - same_site: SameSite value ('Strict', 'Lax', 'None')
  - expires: Expiration timestamp (epoch)
  - priority: Cookie priority

=head2 delete($name, %options)

Delete a cookie.

Options:
  - url: URL to match
  - domain: Domain to match
  - path: Path to match

=head2 clear()

Clear all browser cookies.

=head2 save($file)

Save all cookies to a JSON file.

=head2 load($file)

Load cookies from a JSON file.

=head2 to_header(%options)

Get cookies as HTTP Cookie header string.

=head2 from_header($header, %options)

Parse and set cookie from Set-Cookie header.

=head2 error()

Get the last error message.

=head1 AUTHOR

Generated for chrome-driver plugin

=cut
