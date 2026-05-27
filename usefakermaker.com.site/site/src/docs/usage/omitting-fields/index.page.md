# Omitting Fields

Sometimes you want a field present, other times you don't. This is often the case when you want to skip fields which have null or empty values.

```ruby
FakerMaker.factory :user do
  name {'Patsy Stone'}
  email(omit: :nil) {'patsy@fabulous.co.uk'}
  admin {false}
end

FM[:user].build.as_json
=> {:name=>"Patsy Stone", :email=>"patsy@fabulous.co.uk", :admin=>false}

FM[:user].build( attributes: { email: nil } ).as_json
=> {:name=>"Patsy Stone", :admin=>false}
```

The `omit` modifier can take a single value or an array. If it is passed a value and the attribute equals this value, it will not be included in the output from `as_json` (which returns a Ruby Hash) or in `to_json` methods.

There are four special modifiers:

* `:nil` (symbol) to omit output when the attribute is set to nil.
* `:empty` to omit output when the value is an empty string, an empty array or an empty hash.
* `:always` to never output this attribute.
* `FakerMaker::OMIT` to omit output only when the attribute is set to this token value.

These can be mixed with real values, e.g.

```ruby
FakerMaker.factory :user do
  name {'Patsy Stone'}
  email(omit: [:nil, :empty, 'test@foobar.com']) {'patsy@fabulous.co.uk'}
  admin {false}
end
```

## Using the omit token

You may want a field that can be excluded, but can also be set to the literal values of `nil` or an empty string/array/hash.

`FakerMaker::OMIT` is a token value that can provide this flexibility, e.g.

```ruby
FakerMaker.factory :user do
  name(omit: FakerMaker::OMIT) {'Patsy Stone'}
  email(omit: :nil) {'patsy@fabulous.co.uk'}
  admin(omit: :empty) {false}
end

FM[:user].build( attributes: { name: FakerMaker::OMIT } ).as_json
=> {:email=>"patsy@fabulous.co.uk", :admin=>false}

FM[:user].build( attributes: { name: nil, email: nil } ).as_json
=> {:name=>nil, :admin=>false}

FM[:user].build( attributes: { name: '', admin: '' } ).as_json
=> {:name=>"", :email=>"patsy@fabulous.co.uk"}
```
