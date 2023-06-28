CREATE SUPERUSER ROLE user1 { SET password := 'password2'; };
CREATE TYPE Bootstrap {
    CREATE PROPERTY name -> str;
};
CREATE TYPE Bootstrap2 EXTENDING Bootstrap;
