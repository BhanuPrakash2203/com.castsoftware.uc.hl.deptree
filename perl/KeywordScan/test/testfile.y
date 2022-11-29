		01  WS-RPT-COLUMNS.
		   10 WS-C OCCURS 2 TIMES
           10 WS-COL3             PIC X(4)   VALUE 'DEPT'.
           10 FILLER              PIC X(2).
           10 WS-COL4             PIC X(12)  VALUE 'HIREDATE'.
           10 FILLER              PIC X(2).
           10 WS-COL5             PIC X(12)  VALUE 'SALARY'.
           10 FILLER              PIC X(2).
           10 WS-COL6             PIC X(12)  VALUE 'BONUS'.
           10 FILLER              PIC X(23).
                                                                        
      ******************************************************************
      * VARIABLES                                 
      ******************************************************************
       01  ERROR-MESSAGE.                                               
               02  ERROR-LEN   PIC S9(4)  COMP VALUE +960.              
               02  ERROR-TEXT  PIC X(80) OCCURS 12 TIMES                
                                    INDEXED BY ERROR-INDEX.       
       77  ERROR-TEXT-LEN      PIC S9(9)  COMP VALUE +80.               
       01 ERROR-INDEX PIC 99.
                                                                        
      /                                                                 
      ******************************************************************
      * SQLCA AND DCLGENS FOR TABLES                                    
      ******************************************************************
                EXEC SQL INCLUDE SQLCA  END-EXEC.                       
                                                                        
                EXEC SQL INCLUDE EMP
                END-EXEC.                                               
                                                                                                                                        
      /                                                                 
      ******************************************************************
      * SQL CURSORS AND STATEMENTS                                      
      ******************************************************************
                                                                        
                EXEC SQL DECLARE C1 CURSOR                                
                  SELECT                                                
                      EMPNO,
                      FIRSTNAME,
                      MIDINIT,
                      LASTNAME,
                      WORKDEPT,
                      PHONENO,
                      HIREDATE,
                      JOB,
                      EDLEVEL,
                      SEX,
                      SALARY,
                      BONUS,
                      COMM
                    FROM EMP                                            
                    WHERE BONUS >= 10000                         
                END-EXEC.                                               
                                                                        
      /                                                                 
       PROCEDURE DIVISION.                                                                                                                     
      ******************************************************************
      * MAIN PROGRAM ROUTINE                                            
      ******************************************************************
       MAINLINE.                                                        
                                  
                PRINT WS-RPT-HEADER.
                
                PRINT WS-RPT-COLUMNS.
                                  
                PERFORM 2000-PROCESS                                    
                THRU    2000-EXIT.                                      
                                                                                                                                         
                STOP RUN.                                                 
     
      /                                                                 
      ******************************************************************
      * 2100-OPEN-CURSOR                                                    
      ******************************************************************
       2100-OPEN-CURSOR.                                                    

                EXEC SQL                                                
                  OPEN  C1                                              
                END-EXEC.                                               
                                                                        
                MOVE SQLCODE TO WS-SQLCODE.                             
                DISPLAY 'WS-SQLCODE ON OPEN = ' WS-SQLCODE.         
                                                                        
       2100-EXIT.                                                       
                EXIT.                                                   

      /                                                                 
      ******************************************************************
      * 2200-FETCH-CURSOR                                                    
      ******************************************************************
       2200-FETCH-CURSOR.                                                    

                EXEC SQL                                                
                    FETCH C1                                            
                    INTO  :WS-EMPNO,
                          :WS-FIRSTNAME,
                          :WS-MIDINIT,
                          :WS-LASTNAME,
                          :WS-DEPT,
                          :WS-PHONE,
                          :WS-HIREDATE,
                          :WS-JOB,
                          :WS-EDLEVEL,
                          :WS-SEX,
                          :WS-BIRTHDATE,
                          :WS-SALARY,
                          :WS-BONUS,
                          :WS-COMM
                END-EXEC.                                               
      
      /                                                                 
      ******************************************************************
      * 2300-CLOSE-CURSOR                                                    
      ******************************************************************
       2300-CLOSE-CURSOR.                                                    

                EXEC SQL                                                
                  CLOSE  C1                                              
                END-EXEC.                                               
                                                                        
                MOVE SQLCODE TO WS-SQLCODE.                             
                DISPLAY 'WS-SQLCODE ON CLOSE = ' WS-SQLCODE.         
                                                                        
       2300-EXIT.                                                       
                EXIT.                                                   

      