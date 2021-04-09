use Test;
use IO::Socket::Async::SSL;

my constant TEST_PORT = 54335;

my $server = IO::Socket::Async::SSL.listen(
    'localhost', TEST_PORT,
    server-private-key-file => 't/certs-and-keys/server.key',
    server-certificate-file => 't/certs-and-keys/server-bundle.crt',
    ciphers => 'DHE-RSA-AES256-GCM-SHA384'
);
my $echo-server-tap = $server.tap: -> $conn {
    $conn.Supply(:bin).tap: -> $data {
        $conn.write($data);
    }
}
END $echo-server-tap.close;

lives-ok
    {
        my $s = await IO::Socket::Async::SSL.connect('localhost', TEST_PORT,
            server-ca-file => 't/certs-and-keys/ca.crt',
            ciphers => 'DHE-RSA-AES256-GCM-SHA384');
        $s.close;
    },
    'Connection with cipher doing key exchange works';

done-testing;
