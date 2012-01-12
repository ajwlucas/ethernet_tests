#include <stdio.h>
#include <string.h>
#include <print.h>

int check_test_frame(int len, unsigned int expected_seq, unsigned char bytes[])
{
    unsigned int seq_num;
    
    memcpy(&seq_num, &bytes[16], 4);
    
    if (seq_num != expected_seq)
    {
        printstr("Error receiving frame, unexpected seq = "); 
        printintln(seq_num);
        return 0;
    }
    
    for (int i=20; i < len; i++)
    {
        if (bytes[i] != i)
        {
            printstr("Error receiving frame, unexpected byte = ");
			printintln(i);
            return 0;
        }
    }

	return 1;
}
