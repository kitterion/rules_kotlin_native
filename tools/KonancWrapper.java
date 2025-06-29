package rules_kotlin_native;

import org.jetbrains.kotlin.cli.utilities.MainKt;

import java.util.Arrays;

public class KonancWrapper {
    public static void main(String[] args) {
        if (args.length > 0 && args[0].equals("konanc")) {
            String cwd = System.getProperty("user.dir");

            args = Arrays.copyOf(args, args.length + 2);
            args[args.length - 2] = "-Xklib-relative-path-base=" + cwd;
            args[args.length - 1] = "-Xdebug-prefix-map=" + cwd + "=.";
        }

        MainKt.main(args);
    }
}
