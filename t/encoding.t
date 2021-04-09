use Test;
use IO::Socket::Async::SSL;

my constant TEST_PORT = 54331;

my $ready = Promise.new;
start react {
    my %conf =
        server-private-key-file => 't/certs-and-keys/server.key',
        server-certificate-file => 't/certs-and-keys/server-bundle.crt';
    whenever IO::Socket::Async::SSL.listen('localhost', TEST_PORT, |%conf) -> $conn {
        whenever $conn.Supply(:enc('utf-8')) -> $str {
            $conn.print($str.uc);
        }
    }
    $ready.keep(True);
}
await $ready;

my $enc = "пиво\n".encode('utf-8');
my $conn = await IO::Socket::Async::SSL.connect(
    'localhost', TEST_PORT,
    enc => 'utf-8',
    server-ca-file => 't/certs-and-keys/ca.crt'
);
await $conn.write($enc.subbuf(0, 3));
await $conn.write($enc.subbuf(3));

my $got = '';
await Promise.anyof: Promise.in(5), start react {
    whenever $conn.Supply {
        $got ~= $_;
        done if $got.chars >= 4;
    }
}
is $got, "ПИВО\n", 'UTF-8 decoding with bytes over boundaries correctly handled';

done-testing;
