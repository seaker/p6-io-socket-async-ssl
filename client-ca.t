use Test;
use IO::Socket::Async::SSL:auth<github:seaker>;
#use NativeCall;

#sub ssl-err-msg(CArray[uint8], uint64 --> int64) is native('/usr/local/lib/openssl-err-msg.so') is symbol('openssl_error_message') { * }

#sub print-ssl-error {
#    constant buf_len = 1024;
#    state $buf;
#    BEGIN { $buf = CArray[uint8].allocate(buf_len) }
#
#    my Int $err-bytes = ssl-err-msg($buf, buf_len);
#    warn 'cannot get openssl error message' unless $err-bytes > 0;
#    put "openssl error: { Blob.new($buf[^$err-bytes]).decode }";
#}

sub posit(*@a) {
    my $fr = callframe(5);
    my Str $msg = "{ $fr.line }\@{ $fr.file }";
    $msg ~= " $fr.code.name" if $fr.code ~~ Routine;

    note $msg;
    callsame;
}

#&(IO::Socket::Async.^find_method('connect')).wrap(&posit);

my constant TEST_PORT = 54340;

my $server = IO::Socket::Async::SSL.listen(
    'localhost', TEST_PORT,
    server-private-key-file => 't/certs-and-keys/server.key',
    server-certificate-file => 't/certs-and-keys/server-bundle.crt',
    ca-certificate-file     => 't/certs-and-keys/internim.crt',
);
isa-ok $server, Supply, 'listen method returns a Supply';

dies-ok { await IO::Socket::Async.connect('localhost', TEST_PORT) }, 'Server not listening until Supply is tapped';

{
    my $echo-server-tap = $server.tap: -> $conn {
        $conn.Supply(:bin).tap: -> $data {
            $conn.write($data);
        }
    }

    my $raw-conn;
    lives-ok { $raw-conn = await IO::Socket::Async.connect('localhost', TEST_PORT) },
        'Server listens after Supply is tapped';
    $raw-conn.close;

    my $ssl-conn;
    lives-ok { $ssl-conn = await IO::Socket::Async::SSL.connect(
            'localhost', TEST_PORT,
            server-ca-file          => 't/certs-and-keys/ca.crt',           # must be ca.crt
            client-ca-file          => 't/certs-and-keys/user01.crt',
            client-private-key-file => 't/certs-and-keys/user01.key',
        )
        #print-ssl-error;
    }, 'Can establish and SSL connection to the SSL server';

    lives-ok { $ssl-conn.write('penguin'.encode('ascii')) }, 'Can write to the SSL server';

    my $incoming = $ssl-conn.Supply(:bin);
    isa-ok $incoming, Supply, 'Can get a Supply of incoming data';
    my $got = '';
    await Promise.anyof: Promise.in(5), start react {
        whenever $incoming {
            $got ~= .decode('ascii');
            done if $got eq 'penguin';
        }
    }
    is $got, 'penguin', 'SSL echo server got back expected data';

#`[
    lives-ok { $ssl-conn.close }, 'Can close the SSL server connection';

    throws-like { await IO::Socket::Async::SSL.connect('localhost', TEST_PORT) },
        X::IO::Socket::Async::SSL::Verification,
        'Without specifying a CA, our self-signed server fails verification';

    $echo-server-tap.close;
    dies-ok { await IO::Socket::Async.connect('localhost', TEST_PORT) },
        'Server not listening after tap is closed';
]
}

#`[
    my $server = IO::Socket::Async::SSL.listen(
        '127.0.0.1', TEST_PORT,
        server-private-key-file => 't/certs-and-keys/server.key',
        server-certificate-file => 't/certs-and-keys/server-bundle.crt'
    );
    my $echo-server-tap = $server.tap: -> $conn {
        $conn.Supply(:bin).tap: -> $data {
            $conn.write($data);
        }
    }
    throws-like { await IO::Socket::Async::SSL.connect('127.0.0.1', TEST_PORT,
            server-ca-file => 't/certs-and-keys/ca.crt') },
        X::IO::Socket::Async::SSL::Verification,
        'When we connect to 127.0.0.1, certificate for localhost will not do';
    $echo-server-tap.close;
]

#`[
if IO::Socket::Async::SSL.supports-alpn {
    my $server = IO::Socket::Async::SSL.listen(
        'localhost', TEST_PORT+1,
        server-private-key-file => 't/certs-and-keys/server.key',
        server-certificate-file => 't/certs-and-keys/server-bundle.crt',
        alpn => <h2 http/1.1>
    );

    my $echo-server-tap = $server.tap: -> $conn {
        ok $conn.socket-host eq '127.0.0.1'|'::1', 'socket-host works';
        $conn.supply(:bin).tap: -> $data { $conn.write($data); }
    };

    my $conn = await IO::Socket::Async::SSL.connect(
        'localhost', TEST_PORT+1,
        server-ca-file => 't/certs-and-keys/ca.crt',
        alpn => <h2 http/1.1>
    );
    is $conn.alpn-result, 'h2', 'Simple server-side ALPN works';
    $conn.?close;
    $echo-server-tap.close;
} else {
    skip "no alpn support in this ssl version";
}

if IO::Socket::Async::SSL.supports-alpn {
    my $server = IO::Socket::Async::SSL.listen(
        'localhost', TEST_PORT+1,
        server-private-key-file => 't/certs-and-keys/server.key',
        server-certificate-file => 't/certs-and-keys/server-bundle.crt',
        alpn => sub (@options) {
            ok @options.join(', ') eq 'h2, http/1.1', 'Passed protocols are correct';
            any(@options) eq 'h2' ?? 'h2' !! Nil;
        }
    );

    my $echo-server-tap = $server.tap: -> $conn {
        $conn.supply(:bin).tap: -> $data {
            $conn.write($data);
        }
    };

    my $conn = await IO::Socket::Async::SSL.connect(
        'localhost', TEST_PORT+1,
        server-ca-file => 't/certs-and-keys/ca.crt',
        alpn           => <h2 http/1.1>
    );
    is $conn.alpn-result, 'h2', 'Server-side ALPN with a subroutine works';
    $conn.?close;
    $echo-server-tap.close;
} else {
    skip "no alpn support in this ssl version", 2;
}

if IO::Socket::Async::SSL.supports-alpn {
    my $server = IO::Socket::Async::SSL.listen(
        'localhost', TEST_PORT+1,
        server-private-key-file => 't/certs-and-keys/server.key',
        server-certificate-file => 't/certs-and-keys/server-bundle.crt',
        alpn => <h2 http/1.1>
    );

    my $echo-server-tap = $server.tap: -> $conn {
        isnt $conn.alpn-result, Nil, 'ALPN on server-side is set';
        $conn.supply(:bin).tap: -> $data {
            $conn.write($data);
        }
    };

    my $p1 = start {
        my $conn1 = await IO::Socket::Async::SSL.connect(
            'localhost', TEST_PORT+1,
            server-ca-file => 't/certs-and-keys/ca.crt',
            alpn => <http/1.1>
        );
        my $result = $conn1.alpn-result;
        $conn1.?close;
        $result
    }
    my $p2 = start {
        my $conn2 = await IO::Socket::Async::SSL.connect(
            'localhost', TEST_PORT+1,
            server-ca-file => 't/certs-and-keys/ca.crt',
            alpn => <h2 http/1.1>
        );
        my $result = $conn2.alpn-result;
        $conn2.?close;
        $result
    }
    await Promise.anyof(Promise.in(5), Promise.allof($p1, $p2));
    ok $p1.status ~~ Kept, 'Multiple clients with ALPN work';
    ok $p2.status ~~ Kept, 'Multiple clients with ALPN work';
    is $p1.result, 'http/1.1', 'Negotiation is correct (1)';
    is $p2.result, 'h2', 'Negotiation is correct (2)';
    $echo-server-tap.close;
} else {
    skip "no alpn support in this ssl version", 5;
}

# Check PKCS12 bundle
my $server3 = IO::Socket::Async::SSL.listen(
    'localhost', TEST_PORT+3,
    server-certificate-file => 't/certs-and-keys/server-bundle.p12'
);
isa-ok $server3, Supply, 'listen method returns a Supply with PKCS12 bundle';
my $echo-server3-tap = $server3.tap: -> $conn {
    $conn.Supply(:bin).tap: -> $data {
        $conn.write($data);
    }
}
my $ssl-conn;
lives-ok { $ssl-conn = await IO::Socket::Async::SSL.connect(
        'localhost', TEST_PORT + 3,
         server-ca-file => 't/certs-and-keys/ca.crt'
    )
}, 'Can establish and SSL connection to the SSL server';

#non existing/readable cert File
my $server4 = IO::Socket::Async::SSL.listen(
    'localhost', TEST_PORT+4,
    server-certificate-file => 't/certs-and-keys/not_there.crt'
);

throws-like { $server4.tap }, X::IO::Socket::Async::SSL, 'Certfile not there';
}
#]

done-testing;

# vi:ft=raku
