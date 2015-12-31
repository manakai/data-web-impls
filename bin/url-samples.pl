use strict;
use warnings;
use Path::Tiny;
use Web::URL::Canonicalize qw(canonicalize_parsed_url resolve_url serialize_parsed_url parse_url);

{
  my $path = path (__FILE__)->parent->parent->child
      ('local/psl.txt');
  my @domain;
  for (split /\x0D?\x0A/, $path->slurp_utf8) {
    if (/\S/) {
      push @domain, $_;
      # XXX ! * prefixes are not supported
    }
  }
  my $re = join '|', map { quotemeta $_ } @domain;
  sub etld1 ($) {
    return $1 if $_[0] =~ m{([^./]+\.(?:$re))\z}o;
    return [split m{//}, $_[0]]->[-1];
  } # etld1
}

sub ascii_origin ($) {
  my $url = canonicalize_parsed_url resolve_url serialize_parsed_url parse_url ($_[0]), parse_url 'about:blank';
  return undef unless defined $url->{scheme};
  return undef unless defined $url->{host};
  return $url->{scheme} . '://' . $url->{host}
      . (defined $url->{port} ? ':' . $url->{port} : '');
} # ascii_origin

my $urls = {};
while (<>) {
  if (/\S/) {
    chomp;
    my $origin = ascii_origin $_;
    next unless defined $origin;
    push @{$urls->{$origin} ||= []}, $_;
  }
}

my @line;
my %found;
for my $origin (sort { $b cmp $a } keys %$urls) {
  my $site = etld1 $origin;
  next if $found{$site}++;
  my $url = [sort { $a cmp $b } @{$urls->{$origin}}]->[0];
  push @line, "$site $url\n";
}
print for sort { $a cmp $b } @line;

## License: Public Domain.
