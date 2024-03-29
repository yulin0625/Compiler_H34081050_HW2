/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_hw_common.h" //Extern variables that communicate with lex
    #define YYDEBUG 1
    int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol(char* name, char* type, char* func_sig, int is_param_function);
    static Symbol lookup_symbol(char* name, int tables);
    static void dump_symbol(int level);

    static char* get_exp_type(char* name);
    static int check_type(char* name);
    /* Global variables */
    // bool HAS_ERROR = false;
    int address = 0;
    int level = -1;
    int is_func = 0;
    char types[10];
    char operation[10];
    Symbol symbol_table[30][40];
    int table_size[30];
    Symbol *current;//current read in token

    //record function information
    char func_name[15];
    int paraList_not_null;
    char func_signature[15];
    char return_type[10];

%}

/* %error-verbose */

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    char *s_val;
    // int i_val;
    // float f_val;
    /* ... */
}

/* Token without return */
%token VAR 
%token INT FLOAT BOOL STRING
%token INC DEC GEQ LEQ EQL NEQ 
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token PACKAGE
%token FUNC RETURN DEFAULT

/* Token with return, which need to sepcify type */
%token <s_val> INT_LIT FLOAT_LIT STRING_LIT BOOL_LIT
%token <s_val> IDENT NEWLINE 
%token <s_val> LAND LOR PRINT PRINTLN 
%token <s_val> IF ELSE FOR SWITCH CASE


/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type Literal Lvalue Condition
%type <s_val> PrintStmt AssignmentStmt SimpleStmt 
%type <s_val> IncDecStmt ExpressionStmt ForStmt SwitchStmt CaseStmt
%type <s_val> Expression LandExpr AddExpr MulExpr 
%type <s_val> CmpExpr PrimaryExpr UnaryExpr ConversionExpr IndexExpr
%type <s_val> Operand Assign_op Unary_op  Cmp_op Add_op Mul_op Block

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : PackageStmt NEWLINE
    | FunctionDeclStmt
    | NEWLINE
;

PackageStmt
    : PACKAGE IDENT { 
        create_symbol();
        printf("package: %s\n", $2); 
    }
;

FunctionDeclStmt
    : FUNC IDENT {
        strcpy(func_name, $2);
        printf("func: %s\n", func_name);
        create_symbol();
    }
    '(' { strcpy(func_signature, "("); } 
    ParameterList
    ')' { strcat(func_signature, ")"); } 
    ReturnType {
        strcat(func_signature, return_type);
    	printf ("func_signature: %s\n", func_signature);
    	insert_symbol(func_name, "func", func_signature, 0);
    }
    FuncBlock
;

ParameterList
    : Parameter
    | ParameterList ',' Parameter
;

Parameter
    : IDENT Type {
        char type[20];
        char param_type[20];

        if(strcmp($2, "int32")==0){
            strcpy(param_type,"I");
            strcpy(type, "int32");
            strcat(func_signature, "I");
        }
        else if(strcmp($2, "float32")==0){
            strcpy(param_type, "F");
            strcpy(type, "float32");
            strcat(func_signature, "F");
        }
        printf("param %s, type: %s\n", $1, param_type); 
        insert_symbol($1, type, "-", 1);  
    }
    | 
;    

ReturnType
    : INT { strcpy(return_type,"I"); }
    | FLOAT { strcpy(return_type,"F"); }
    | STRING 
    | BOOL
    | { strcpy(return_type,"V"); }
;    

FuncBlock
    : '{' { level++; }
    StatementList 
    '}' { dump_symbol(level); }
;

CallFunc
    : IDENT '(' CallFuncParamList ')' {
        is_func = 1;
    	Symbol t = lookup_symbol($1, 1);
        if(t.addr == -1){
           printf("call: %s%s\n",$1,t.func_sig);
           is_func = 0;
        }
    }
;    

CallFuncParamList
    : CallFuncParam
    | CallFuncParamList ',' CallFuncParam
;    

CallFuncParam
    : Lvalue
    |
;    
//不確定意義，原本為left
Lvalue
    : Literal { $$ = $1; }
    | IDENT { 
    	Symbol t = lookup_symbol($1, 1); 
        if(strcmp(t.name, "NotDefineYet")!=0){ 
            printf("IDENT (name=%s, address=%d)\n", $1, t.addr);            
            strcpy(types, t.type);
        }
        else{
            printf("error:%d: undefined: %s\n", yylineno+1, $1);
        }
    }
;

Literal
    : INT_LIT {
        $$ = "int32"; printf("INT_LIT %s\n", $1); 
    	strcpy(types, "int32");
    }
    | FLOAT_LIT { 
    	$$ = "float32"; 
        printf("FLOAT_LIT %f\n", atof($1));
        strcpy(types, "float32");
    }
    | BOOL_LIT {
        $$ = "bool"; printf("%s\n", $1); strcpy(types, "bool"); 
    }
    | '"' STRING_LIT '"' { 
    	$$ = "string"; printf("STRING_LIT %s\n", $2); strcpy(types, "string"); 
    }
; 

ReturnStmt
    : RETURN Expression {
    	if(strcmp(return_type,"I")==0)
    		printf("ireturn\n");
    	else if(strcmp(return_type,"F")==0)
    		printf("freturn\n");
    }
    | RETURN { printf("return\n"); }
;    

Block
    : '{' { create_symbol(); }
    StatementList
    '}' { dump_symbol(level); }
;

StatementList 
    : StatementList Statement
    | Statement
;

Statement
    : DeclarationStmt NEWLINE
    | FunctionDeclStmt NEWLINE
    | SimpleStmt NEWLINE
    | CallFunc
    | Block
    | IfStmt
    | ForStmt
    | SwitchStmt
    | CaseStmt
    | PrintStmt NEWLINE
    | ReturnStmt NEWLINE
    | NEWLINE
;  

SimpleStmt
    : AssignmentStmt 
    | ExpressionStmt 
    | IncDecStmt
;

ExpressionStmt
    : Expression
;

Expression
    : LandExpr
    | Expression LOR LandExpr {
        $$ = "bool"; strcpy(types, "bool");
	    if(strcmp($1, "int32")== 0 || strcmp($3, "int32")==0){
		    yyerror("invalid operation: (operator LOR not defined on int32)");
	    }
	    if(strcmp($1, "float32")==0 || strcmp($3, "float32")==0 ){
		    yyerror("invalid operation: (operator LOR not defined on float32)");
	    }
	    printf("LOR\n"); 
    }
;    

LandExpr
    : CmpExpr //ex: x>1
    | LandExpr LAND CmpExpr { //ex: x>1 && y>2 && z>3 
        $$ = "bool"; strcpy(types, "bool");
	    if(strcmp($1, "int32")==0 || strcmp($3, "int32")==0){
		    yyerror("invalid operation: (operator LAND not defined on int32)");
	    }
	    if(strcmp($1, "float32")==0 || strcmp($3, "float32")==0){
		    yyerror("invalid operation: (operator LAND not defined on float32)");
	    }
	    printf("LAND\n"); 
    }
;    

CmpExpr
    : AddExpr
    | CmpExpr Cmp_op AddExpr {
        if(strcmp(get_exp_type($1), "null")==0)
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno+1, $2, "ERROR", types); //倒數第二個 "ERROR" ??
        $$ = $2;
        printf("%s\n", $2); strcpy(types, "bool");
    }
;    

Cmp_op
    : EQL { $$ = "EQL"; }
    | NEQ { $$ = "NEQ"; } 
    | '<' { $$ = "LSS"; }
    | LEQ { $$ = "LEQ"; }
    | '>' { $$ = "GTR"; }
    | GEQ { $$ = "GEQ"; }
;    

AddExpr
    : MulExpr
    | AddExpr Add_op MulExpr{
        if(strcmp(get_exp_type($1), "POS")!=0 &&  strcmp(get_exp_type($1), "NEG")!=0 && strcmp(get_exp_type($1), "bool")!=0 && strcmp(get_exp_type($1), types)!=0)
    	printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, operation, get_exp_type($1), types);
        printf("%s\n", $2); 
    }
;    

Add_op
    : '+' { $$ = "ADD"; strcpy(operation, "ADD"); }
    | '-' { $$ = "SUB"; strcpy(operation, "SUB"); }
;    

MulExpr
    : UnaryExpr
    | MulExpr Mul_op UnaryExpr {
        if(strcmp($2, "REM")==0)
            if(strcmp(get_exp_type($1), "float32")==0 || strcmp(get_exp_type($3), "float32")==0)
                yyerror("invalid operation: (operator REM not defined on float32)"); 
        printf("%s\n", $2); 
    }
;      

Mul_op
    : '*' { $$ = "MUL"; strcpy(operation, "MUL"); }
    | '/' { $$ = "QUO"; strcpy(operation, "QUO"); }
    | '%' { $$ = "REM"; strcpy(operation, "REM"); }
;    

UnaryExpr
    : PrimaryExpr
    | Unary_op UnaryExpr { printf("%s\n", $1); }
;    

Unary_op
    : '+' { $$ = "POS"; }
    | '-' { $$ = "NEG"; }
    | '!' { $$ = "NOT"; }
;    

PrimaryExpr
    : Operand { $$ = $1; }
    | ConversionExpr
    | IndexExpr
;    

Operand
    : Lvalue
    | '(' Expression ')' { $$ = $2; }
;       

IndexExpr 
    : PrimaryExpr '[' Expression ']' { strcpy(types, "null"); }
;

ConversionExpr
    : Type '(' Expression ')' {
        if(check_type($3)){
            printf("%c2%c\n", $3[0], $1[0]);
    	}
        else{
            Symbol t = lookup_symbol($3, 1);
            if(strcmp(t.name, "NotDefineYet")!=0){
                printf("%c2%c\n", t.type[0], $1[0]);
            }
    	}
    	strcpy(types, $1); 
    }
;    

IncDecStmt
    : Expression INC { printf("INC\n"); }
    | Expression DEC { printf("DEC\n"); }
;    

DeclarationStmt
    : VAR IDENT Type '=' Expression {
        insert_symbol($2, $3, "-", 0); 
    }
    | VAR IDENT Type {
      	insert_symbol($2, $3, "-", 0);  
    }
    | VAR IDENT Type '=' CallFunc {
      	insert_symbol($2, $3, "-", 1);  	
    }
;

AssignmentStmt
    : Lvalue Assign_op Expression { 
    	if(strcmp(get_exp_type($1), "null")==0)
        	printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, "ERROR", types); 
    	if(strcmp(get_exp_type($1), "null")!=0 &&  strcmp(types, "null")!=0 && strcmp(get_exp_type($1), types) != 0){
        	printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, get_exp_type($1), types);
    	}	
    	printf("%s\n", $2);
    }
; 

Assign_op
    : '=' { $$ = "ASSIGN"; }
    | ADD_ASSIGN { $$="ADD"; }
    | SUB_ASSIGN { $$="SUB"; }
    | MUL_ASSIGN { $$="MUL"; }
    | QUO_ASSIGN { $$="QUO"; }
    | REM_ASSIGN { $$="REM"; }
;    

Condition
    : Expression { 
        if(strcmp("null", get_exp_type($1))!=0 )
            if(strcmp("int32", get_exp_type($1)) == 0 || strcmp("float32", get_exp_type($1))== 0){
                printf("error:%d: non-bool (type %s) used as for condition\n", yylineno+1, get_exp_type($1));
            }        
    }
;

IfStmt
    : IF Condition Block
    | IF Condition Block ELSE IfStmt
    | IF Condition Block ELSE Block
;    

ForStmt
    : FOR Condition Block
    | FOR SimpleStmt ';' Condition ';' SimpleStmt Block
;    

SwitchStmt
    : SWITCH Expression Block
;

CaseStmt 
    : CASE INT_LIT ':' {printf("case %s\n",$<s_val>2);} Block  
    | DEFAULT ':' Block        
;

Type
    : INT { $$ = "int32"; }
    | FLOAT { $$ = "float32"; }
    | STRING { $$ = "string"; }
    | BOOL { $$ = "bool"; }
;

PrintStmt
    : PRINT '(' Expression ')'{
    	if(check_type($3)){
    		printf("PRINT %s\n", $3);
    	}
    	else{
    		Symbol t = lookup_symbol($3, 1);
        	if(t.addr == -1){
            		yyerror("print func symbol");
        	}
            else{
            		printf("PRINT %s\n", t.type);
        	}
    	}
    	strcpy(types, "null");
    }
    | PRINTLN '(' Expression ')' {
    	if(check_type($3)){
    		printf("PRINTLN %s\n", $3);
    	}
    	else{
    		Symbol t = lookup_symbol($3, 1);
        	if(t.addr == -1){
            		yyerror("print func symbol");
        	}
            else{
            		printf("PRINTLN %s\n", t.type);
        	}
    	}
    	strcpy(types, "null");        
    }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if(argc == 2){
        yyin = fopen(argv[1], "r");
    } 
    else{
        yyin = stdin;
    }

    current = (Symbol*)malloc(sizeof(Symbol));

    yylineno = 0;
    yyparse();

    dump_symbol(level);

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}

static void create_symbol() {
    level++;
    printf("> Create symbol table (scope level %d)\n", level);
}

static void insert_symbol(char* name, char* type, char* func_sig, int is_param) {
    Symbol t = lookup_symbol(name, 0);
    
    if(strcmp(t.name, "NotDefineYet")!=0){ //redeclared error, but still need to insert
        printf("error:%d: %s redeclared in this block. previous declaration at line %d\n", yylineno, name, t.lineno);
    }

    /*insert part*/
    if(strcmp(type, "func")==0){ //whether its type is function
    	level--;
    	symbol_table[level][table_size[level]].addr = -1;
    	symbol_table[level][table_size[level]].lineno = yylineno+1;
    }
    else if(is_param==0){
    	symbol_table[level][table_size[level]].addr = address;
    	symbol_table[level][table_size[level]].lineno = yylineno;
    	address++;
    }
    else{ //whether its a parameter or the value is from calling function
        symbol_table[level][table_size[level]].addr = address;
    	symbol_table[level][table_size[level]].lineno = yylineno+1;
    	address++;
    }
    strcpy(symbol_table[level][table_size[level]].name, name);
    strcpy(symbol_table[level][table_size[level]].type, type);
    strcpy(symbol_table[level][table_size[level]].func_sig, func_sig);
    
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, symbol_table[level][table_size[level]].addr, level);
    table_size[level]++;
}

static Symbol lookup_symbol(char* name, int tables){
    /*function*/
    if(is_func){
    	for(int i=0; i<table_size[0]; i++){
            if(strcmp(symbol_table[0][i].name, name)==0)
                return symbol_table[0][i];
	    }
        Symbol node;
        strcpy(node.name, "NotDefineYet");

        return node;
    }
    /*non function*/
    else{
        if(tables!=0){ //all symbol_table
            for(int i=level; i>=0; i--){
                for(int j=0; j<table_size[i]; j++){
                    if(0 == strcmp(symbol_table[i][j].name, name))
                        return symbol_table[i][j];
                }
            }

            Symbol node;
            strcpy(node.name, "NotDefineYet");
            return node;
        }
    	else{ //current symbol_table
            for(int i=0; i<table_size[level]; i++){
                if(0 == strcmp(symbol_table[level][i].name, name))
                    return symbol_table[level][i];
	        }

            Symbol node;
            strcpy(node.name, "NotDefineYet");
            return node;
    	}
    }
}

static void dump_symbol(int scope_level){
    printf("\n> Dump symbol table (scope level: %d)\n", scope_level);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Func_sig");
    for(int i=0; i < table_size[scope_level]; i++){
        printf("%-10d%-10s%-10s%-10d%-10d%-10s\n",
            i, symbol_table[scope_level][i].name, symbol_table[scope_level][i].type, symbol_table[scope_level][i].addr, symbol_table[scope_level][i].lineno, symbol_table[scope_level][i].func_sig);
    }
    table_size[level] = 0;
    printf("\n");      
    level--;
}

static char* get_exp_type(char* name){
    char* type[10] = {"int32", "float32", "bool", "string",
                    "NEG", "POS", "GTR", "LSS", "NEQ", "EQL"};
    int exist=0;
    for(int i = 0; i<10; i++){
        if(strcmp(name, type[i])==0){
           	exist=1;
            break;
        } 
    }
    if(exist==0){
        *current = lookup_symbol(name, 1);
        if(strcmp(current->name, "NotDefineYet")!=0){
            return current->type;
        }
        else{
            return "null";
        }
    }

    return name;
}

static int check_type(char* name){
        char* type[4] = {"int32",
                     "float32",
                     "bool",
                     "string"};
    for(int i = 0; i < 4; i++){
        if(strcmp(name, type[i])==0){
            return 1;
        } 
    }
    return 0;
}