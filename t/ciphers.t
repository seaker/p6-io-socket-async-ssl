use Test;
use IO::Socket::Async::SSL;

my constant TEST_PORT = 54334;

my $server = IO::Socket::Async::SSL.listen(
    'localhost', TEST_PORT,
    server-private-key-file => 't/certs-and-keys/server.key',
    server-certificate-file => 't/certs-and-keys/server-bundle.crt',
    ciphers => 'HIGH'
);
my $echo-server-tap = $server.tap: -> $conn {
    $conn.Supply(:bin).tap: -> $data {
        $conn.write($data);
    }
}
END $echo-server-tap.close;

dies-ok {
    await IO::Socket::Async::SSL.connect(
        'localhost', TEST_PORT,
        server-ca-file => 't/certs-and-keys/ca.crt',
        version        => 1.2,
        ciphers        => 'MEDIUM'
    )
}, 'Connection fails when cipher expectations are not matched';

lives-ok {
    my $s = await IO::Socket::Async::SSL.connect(
        'localhost', TEST_PORT,
        server-ca-file => 't/certs-and-keys/ca.crt',
        ciphers        => 'HIGH'
    );
    $s.close;
}, 'Connection ok when ciphers match up';

dies-ok {
    my $s = await IO::Socket::Async::SSL.connect('localhost', TEST_PORT, ciphers => 'HIGH');
    $s.close;
}, 'Connection ok when ciphers match up, server certificate is a necessity';

done-testing;
