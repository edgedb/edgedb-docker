module default {
    type Counter {
        required property name -> str {
            constraint exclusive;
        };
        required property visits -> int64 {
            default := 0;
        };
    };
};
