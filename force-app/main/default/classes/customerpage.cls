public class customerpage
{
 // Declare variables
    public String name;
    public String email;
    public string phone;
 // Constructor
    public customerpage(String n, String e, string p)
     {
        name = n;
        email = e;
        phone = p;
     }
 // Method to display customer info
    public void showcustomerpage()
     {
        System.debug('Customer Name: ' + name);
        System.debug('Email: ' + email);
        System.debug('Phone: ' + phone);
    }
}