/**
 * @file different_size_rwsplit.cpp Tries INSERTs with size close to 0x0ffffff * N
 * - executes inserts with size: from 0x0ffffff * N - X up to 0x0ffffff * N - X
 * (N = 3, X = 50 or 20 for 'soke' test)
 * - check if Maxscale is still alive
 */


#include <iostream>
#include <maxtest/different_size.h>
#include <maxtest/testconnections.h>

using namespace std;

int main(int argc, char* argv[])
{
    TestConnections* Test = new TestConnections(argc, argv);

    different_packet_size(Test, false);

    Test->set_timeout(180);
    Test->repl->sync_slaves();
    Test->check_maxscale_alive(0);
    int rval = Test->global_result;
    delete Test;
    return rval;
}
