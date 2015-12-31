use strict;
use warnings;
use Path::Tiny;
use Web::DomainName::Canonicalize qw(canonicalize_domain_name);

my $path = path (__FILE__)->parent->parent->child
    ('local/psl.dat');
for (split /\x0D?\x0A/, $path->slurp_utf8) {
  if (m{^\s*//}) {
    next;
  } elsif (/\S/) {
    chomp;
    my $domain = canonicalize_domain_name $_;
    print "$domain\n";
  }
}

## License: Public Domain.
