BEGIN { print "1..1\n" }

eval { require OpenInteract::Package };
if ( $@ ) {
 print "not ";
}
print "ok\n";
