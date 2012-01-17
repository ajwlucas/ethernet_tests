#include <stdio.h>
#include <string.h>
#include <print.h>

int get_seq_num(unsigned char bytes[])
{
    int seq_num;
    memcpy(&seq_num, &bytes[16], 4);

    return seq_num;
}

int check_test_frame(int len, unsigned int expected_seq, unsigned char bytes[])
{
    unsigned int seq_num;
    
    memcpy(&seq_num, &bytes[16], 4);
    
    if (seq_num != expected_seq)
    {
        printstr("Error receiving frame, unexpected seq = "); 
        printint(seq_num);
        printstr(" ,expecting = ");
        printintln(expected_seq);
        return 0;
    }
    
    
    for (int i=20; i < len; i++)
    {
        if (bytes[i] != (i%256))
        {
            printstr("Error receiving frame, unexpected byte = ");
			printintln(i);
            return 0;
        }
    }
    

	return 1;
}
