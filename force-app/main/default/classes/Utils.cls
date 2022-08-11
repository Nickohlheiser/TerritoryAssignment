public with sharing class Utils {
    public static String listToStringSingleQuote(List<SObject> sobjList, String fieldName){
        String returnString = '';

        for(SObject s : sobjList){
            if(returnString.endsWith('\'')){
                returnString += ',';
            }
            returnString += '\'' + s.get(fieldName) + '\'';
        }
        return returnString;
    }

    public static String listToStringSingleQuote(List<String> stringList){
        String returnString = '';

        for(String s : stringList){
            if(returnString.endsWith('\'')){
                returnString += ',';
            }
            returnString += '\'' + s + '\'';
        }
        return returnString;
    }

    public static String listToStringSingleQuote(List<String> stringList, String delimeter, String operator){
        String returnString = '';

        for(String s : stringList){
            if(returnString.endsWith('\'')){
                returnString += ' ' + operator + ' ';
            }
            returnString += delimeter + ' \'' + s + '\'';
        }
        return returnString;
    }
}