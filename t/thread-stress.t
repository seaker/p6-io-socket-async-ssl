use Test;
use IO::Socket::Async::SSL;

my constant TEST_PORT = 54332;

my $ready = Promise.new;
start react {
    my %conf =
        server-private-key-file => 't/certs-and-keys/server.key',
        server-certificate-file => 't/certs-and-keys/server-bundle.crt';
    whenever IO::Socket::Async::SSL.listen('localhost', TEST_PORT, |%conf) -> $conn {
        whenever $conn.Supply(:bin) -> $data {
            whenever $conn.write($data) {}
        }
    }
    $ready.keep(True);
}
await $ready;

await do for ^4 {
    start {
        for 1..50 -> $i {
            my $server-ca-file = 't/certs-and-keys/ca.crt';
            my $conn = await IO::Socket::Async::SSL.connect('localhost', TEST_PORT, :$server-ca-file);
            my $expected = "[string $i]" x (8 * $i);
            await $conn.write($expected.encode('ascii'));
            my $got = '';
            react {
                whenever $conn.Supply(:bin) {
                    $got ~= .decode('ascii');
                    if $got.chars eq $expected.chars {
                        $conn.close;
                        done;
                    }
                }
                whenever Promise.in(5) {
                    $conn.close;
                    done;
                }
            }
            die "Oops ($got ne $expected)" unless $got eq $expected;
        }
    }
}

pass 'Thread stress-test lived';

done-testing;
