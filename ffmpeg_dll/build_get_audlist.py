import sys

if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(1)
    
    file_exeout = sys.argv[1]
    file_configure = sys.argv[2]
    
    try:
        f = open(file_exeout)
        lines_exeout = f.readlines()
    except:
        print('cannot open file: ' + file_exeout)
        sys.exit(1)
    else:
        f.close()
    
    try:
        f = open(file_configure)
        lines_configure = f.readlines()
    except:
        print('cannot open file: ' + file_configure)
        sys.exit(1)
    else:
        f.close()
        
    result = ""
    for configure_arg in lines_configure:
        for exeout_arg in lines_exeout:
            if configure_arg.strip().replace('_', '').lower() in exeout_arg.strip().replace('_', '').lower():
                if len(result) > 0:
                    result += ","
                result += configure_arg.strip()
                break
    print(result)
    sys.exit(0)