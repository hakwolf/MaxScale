/**
 * MXS-2450: Crash on COM_CHANGE_USER with disable_sescmd_history=true
 * https://jira.mariadb.org/browse/MXS-2450
 */

#include <maxtest/testconnections.h>

int main(int argc, char *argv[])
{
    TestConnections test(argc, argv);
    Connection conn = test.maxscales->rwsplit();
    test.expect(conn.connect(), "Connection failed: %s", conn.error());

    for (int i = 0; i < 10; i++)
    {
        test.expect(conn.reset_connection(), "Connection reset failed: %s", conn.error());
    }

    return test.global_result;
}
