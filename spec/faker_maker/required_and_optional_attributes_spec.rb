# frozen_string_literal: true

RSpec.describe FakerMaker::Factory do
  describe '#required_attributes' do
    it 'returns required attributes for a single-level factory' do
      factory = FakerMaker::Factory.new( :flat_required )
      req_attr = FakerMaker::Attribute.new( :name, proc { 'Jane' }, required: true )
      opt_attr = FakerMaker::Attribute.new( :nickname, proc { 'Janey' } )
      factory.attach_attribute( req_attr )
      factory.attach_attribute( opt_attr )
      FakerMaker.register_factory( factory )

      expect( factory.required_attributes ).to eq [req_attr]
    end

    it 'returns an empty array when no attributes are required' do
      factory = FakerMaker::Factory.new( :no_required )
      opt_attr = FakerMaker::Attribute.new( :flavour, proc { 'vanilla' } )
      factory.attach_attribute( opt_attr )
      FakerMaker.register_factory( factory )

      expect( factory.required_attributes ).to eq []
    end

    it 'recurses into embedded factories when the parent attribute is required' do
      child_factory = FakerMaker::Factory.new( :req_child )
      child_req = FakerMaker::Attribute.new( :capacity, proc { '2.0L' }, required: true )
      child_opt = FakerMaker::Attribute.new( :turbo, proc { false } )
      child_factory.attach_attribute( child_req )
      child_factory.attach_attribute( child_opt )
      FakerMaker.register_factory( child_factory )

      parent_factory = FakerMaker::Factory.new( :req_parent )
      parent_req = FakerMaker::Attribute.new( :engine, nil, required: true, factory: :req_child )
      parent_factory.attach_attribute( parent_req )
      FakerMaker.register_factory( parent_factory )

      result = parent_factory.required_attributes
      expect( result.length ).to eq 1
      expect( result.first ).to be_a Hash
      expect( result.first.keys ).to eq [parent_req]
      expect( result.first[parent_req] ).to eq [child_req]
    end

    it 'ignores children of optional parent attributes' do
      child_factory = FakerMaker::Factory.new( :ignored_child )
      child_req = FakerMaker::Attribute.new( :important, proc { 'yes' }, required: true )
      child_factory.attach_attribute( child_req )
      FakerMaker.register_factory( child_factory )

      parent_factory = FakerMaker::Factory.new( :opt_parent_req_child )
      parent_opt = FakerMaker::Attribute.new( :extras, nil, factory: :ignored_child )
      parent_req = FakerMaker::Attribute.new( :id, proc { '123' }, required: true )
      parent_factory.attach_attribute( parent_opt )
      parent_factory.attach_attribute( parent_req )
      FakerMaker.register_factory( parent_factory )

      result = parent_factory.required_attributes
      expect( result ).to eq [parent_req]
    end

    it 'shows all possible factories when multiple are defined' do
      factory_a = FakerMaker::Factory.new( :multi_a )
      attr_a = FakerMaker::Attribute.new( :speed, proc { 'fast' }, required: true )
      factory_a.attach_attribute( attr_a )
      FakerMaker.register_factory( factory_a )

      factory_b = FakerMaker::Factory.new( :multi_b )
      attr_b = FakerMaker::Attribute.new( :power, proc { '150kW' }, required: true )
      factory_b.attach_attribute( attr_b )
      FakerMaker.register_factory( factory_b )

      parent_factory = FakerMaker::Factory.new( :multi_parent )
      parent_attr = FakerMaker::Attribute.new( :drive, nil, required: true, factory: %i[multi_a multi_b] )
      parent_factory.attach_attribute( parent_attr )
      FakerMaker.register_factory( parent_factory )

      result = parent_factory.required_attributes
      expect( result.length ).to eq 1
      expect( result.first ).to be_a Hash
      expect( result.first[parent_attr] ).to contain_exactly( attr_a, attr_b )
    end

    it 'includes parent factory required attributes via inheritance' do
      base_factory = FakerMaker::Factory.new( :base_req )
      base_attr = FakerMaker::Attribute.new( :id, proc { '1' }, required: true )
      base_opt = FakerMaker::Attribute.new( :updated_at, proc { Time.now } )
      base_factory.attach_attribute( base_attr )
      base_factory.attach_attribute( base_opt )
      FakerMaker.register_factory( base_factory )

      derived_factory = FakerMaker::Factory.new( :derived_req, parent: :base_req )
      derived_attr = FakerMaker::Attribute.new( :name, proc { 'Jane' }, required: true )
      derived_factory.attach_attribute( derived_attr )
      FakerMaker.register_factory( derived_factory )

      result = derived_factory.required_attributes
      expect( result ).to contain_exactly( base_attr, derived_attr )
    end

    it 'recurses multiple levels deep' do
      leaf_factory = FakerMaker::Factory.new( :deep_leaf )
      leaf_attr = FakerMaker::Attribute.new( :provider, proc { 'TomTom' }, required: true )
      leaf_factory.attach_attribute( leaf_attr )
      FakerMaker.register_factory( leaf_factory )

      mid_factory = FakerMaker::Factory.new( :deep_mid )
      mid_attr = FakerMaker::Attribute.new( :nav, nil, required: true, factory: :deep_leaf )
      mid_factory.attach_attribute( mid_attr )
      FakerMaker.register_factory( mid_factory )

      top_factory = FakerMaker::Factory.new( :deep_top )
      top_attr = FakerMaker::Attribute.new( :dash, nil, required: true, factory: :deep_mid )
      top_factory.attach_attribute( top_attr )
      FakerMaker.register_factory( top_factory )

      result = top_factory.required_attributes
      expect( result.length ).to eq 1
      expect( result.first ).to be_a Hash
      expect( result.first[top_attr].length ).to eq 1
      expect( result.first[top_attr].first ).to be_a Hash
      expect( result.first[top_attr].first[mid_attr] ).to eq [leaf_attr]
    end

    it 'returns the attribute directly when embedded factory has no matching nested attributes' do
      child_factory = FakerMaker::Factory.new( :all_opt_child )
      child_opt = FakerMaker::Attribute.new( :colour, proc { 'red' } )
      child_factory.attach_attribute( child_opt )
      FakerMaker.register_factory( child_factory )

      parent_factory = FakerMaker::Factory.new( :req_parent_opt_children )
      parent_attr = FakerMaker::Attribute.new( :widget, nil, required: true, factory: :all_opt_child )
      parent_factory.attach_attribute( parent_attr )
      FakerMaker.register_factory( parent_factory )

      result = parent_factory.required_attributes
      expect( result ).to eq [parent_attr]
    end
  end

  describe '#required_attribute_names' do
    it 'returns symbols for a flat factory' do
      factory = FakerMaker::Factory.new( :flat_req_names )
      factory.attach_attribute( FakerMaker::Attribute.new( :name, proc { 'Jane' }, required: true ) )
      factory.attach_attribute( FakerMaker::Attribute.new( :age, proc { 30 }, required: true ) )
      factory.attach_attribute( FakerMaker::Attribute.new( :nickname, proc { 'J' } ) )
      FakerMaker.register_factory( factory )

      expect( factory.required_attribute_names ).to eq %i[name age]
    end

    it 'returns nested hashes with symbol keys for embedded factories' do
      child_factory = FakerMaker::Factory.new( :names_child )
      child_factory.attach_attribute( FakerMaker::Attribute.new( :fuel_type, proc { 'petrol' }, required: true ) )
      FakerMaker.register_factory( child_factory )

      parent_factory = FakerMaker::Factory.new( :names_parent )
      parent_factory.attach_attribute( FakerMaker::Attribute.new( :reg, proc { 'AB12' }, required: true ) )
      parent_factory.attach_attribute( FakerMaker::Attribute.new( :engine, nil, required: true, factory: :names_child ) )
      FakerMaker.register_factory( parent_factory )

      result = parent_factory.required_attribute_names
      expect( result ).to eq [:reg, { engine: [:fuel_type] }]
    end
  end

  describe '#optional_attributes' do
    it 'returns optional attributes for a single-level factory' do
      factory = FakerMaker::Factory.new( :flat_optional )
      req_attr = FakerMaker::Attribute.new( :id, proc { '1' }, required: true )
      opt_attr = FakerMaker::Attribute.new( :nickname, proc { 'Janey' } )
      factory.attach_attribute( req_attr )
      factory.attach_attribute( opt_attr )
      FakerMaker.register_factory( factory )

      expect( factory.optional_attributes ).to eq [opt_attr]
    end

    it 'returns an empty array when no attributes are optional' do
      factory = FakerMaker::Factory.new( :all_required )
      req_attr = FakerMaker::Attribute.new( :id, proc { '1' }, required: true )
      factory.attach_attribute( req_attr )
      FakerMaker.register_factory( factory )

      expect( factory.optional_attributes ).to eq []
    end

    it 'recurses into embedded factories when the parent attribute is optional' do
      child_factory = FakerMaker::Factory.new( :opt_child )
      child_opt = FakerMaker::Attribute.new( :brand, proc { 'Bose' } )
      child_req = FakerMaker::Attribute.new( :model, proc { 'QC45' }, required: true )
      child_factory.attach_attribute( child_opt )
      child_factory.attach_attribute( child_req )
      FakerMaker.register_factory( child_factory )

      parent_factory = FakerMaker::Factory.new( :opt_parent )
      parent_opt = FakerMaker::Attribute.new( :stereo, nil, factory: :opt_child )
      parent_factory.attach_attribute( parent_opt )
      FakerMaker.register_factory( parent_factory )

      result = parent_factory.optional_attributes
      expect( result.length ).to eq 1
      expect( result.first ).to be_a Hash
      expect( result.first.keys ).to eq [parent_opt]
      expect( result.first[parent_opt] ).to eq [child_opt]
    end

    it 'ignores children of required parent attributes' do
      child_factory = FakerMaker::Factory.new( :req_parent_child )
      child_opt = FakerMaker::Attribute.new( :turbo, proc { false } )
      child_factory.attach_attribute( child_opt )
      FakerMaker.register_factory( child_factory )

      parent_factory = FakerMaker::Factory.new( :req_parent_ignores_opt )
      parent_req = FakerMaker::Attribute.new( :engine, nil, required: true, factory: :req_parent_child )
      parent_opt = FakerMaker::Attribute.new( :colour, proc { 'blue' } )
      parent_factory.attach_attribute( parent_req )
      parent_factory.attach_attribute( parent_opt )
      FakerMaker.register_factory( parent_factory )

      result = parent_factory.optional_attributes
      expect( result ).to eq [parent_opt]
    end

    it 'shows all possible factories when multiple are defined' do
      factory_a = FakerMaker::Factory.new( :opt_multi_a )
      attr_a = FakerMaker::Attribute.new( :screen_size, proc { '7 inch' } )
      factory_a.attach_attribute( attr_a )
      FakerMaker.register_factory( factory_a )

      factory_b = FakerMaker::Factory.new( :opt_multi_b )
      attr_b = FakerMaker::Attribute.new( :resolution, proc { '1080p' } )
      factory_b.attach_attribute( attr_b )
      FakerMaker.register_factory( factory_b )

      parent_factory = FakerMaker::Factory.new( :opt_multi_parent )
      parent_attr = FakerMaker::Attribute.new( :display, nil, factory: %i[opt_multi_a opt_multi_b] )
      parent_factory.attach_attribute( parent_attr )
      FakerMaker.register_factory( parent_factory )

      result = parent_factory.optional_attributes
      expect( result.length ).to eq 1
      expect( result.first ).to be_a Hash
      expect( result.first[parent_attr] ).to contain_exactly( attr_a, attr_b )
    end

    it 'includes parent factory optional attributes via inheritance' do
      base_factory = FakerMaker::Factory.new( :base_opt )
      base_opt = FakerMaker::Attribute.new( :updated_at, proc { Time.now } )
      base_req = FakerMaker::Attribute.new( :id, proc { '1' }, required: true )
      base_factory.attach_attribute( base_opt )
      base_factory.attach_attribute( base_req )
      FakerMaker.register_factory( base_factory )

      derived_factory = FakerMaker::Factory.new( :derived_opt, parent: :base_opt )
      derived_opt = FakerMaker::Attribute.new( :nickname, proc { 'J' } )
      derived_factory.attach_attribute( derived_opt )
      FakerMaker.register_factory( derived_factory )

      result = derived_factory.optional_attributes
      expect( result ).to contain_exactly( base_opt, derived_opt )
    end

    it 'returns the attribute directly when embedded factory has no matching nested attributes' do
      child_factory = FakerMaker::Factory.new( :all_req_child )
      child_req = FakerMaker::Attribute.new( :id, proc { '1' }, required: true )
      child_factory.attach_attribute( child_req )
      FakerMaker.register_factory( child_factory )

      parent_factory = FakerMaker::Factory.new( :opt_parent_req_children )
      parent_attr = FakerMaker::Attribute.new( :widget, nil, factory: :all_req_child )
      parent_factory.attach_attribute( parent_attr )
      FakerMaker.register_factory( parent_factory )

      result = parent_factory.optional_attributes
      expect( result ).to eq [parent_attr]
    end
  end

  describe '#optional_attribute_names' do
    it 'returns symbols for a flat factory' do
      factory = FakerMaker::Factory.new( :flat_opt_names )
      factory.attach_attribute( FakerMaker::Attribute.new( :id, proc { '1' }, required: true ) )
      factory.attach_attribute( FakerMaker::Attribute.new( :nickname, proc { 'J' } ) )
      factory.attach_attribute( FakerMaker::Attribute.new( :colour, proc { 'blue' } ) )
      FakerMaker.register_factory( factory )

      expect( factory.optional_attribute_names ).to eq %i[nickname colour]
    end

    it 'returns nested hashes with symbol keys for embedded factories' do
      child_factory = FakerMaker::Factory.new( :opt_names_child )
      child_factory.attach_attribute( FakerMaker::Attribute.new( :brand, proc { 'Pirelli' } ) )
      FakerMaker.register_factory( child_factory )

      parent_factory = FakerMaker::Factory.new( :opt_names_parent )
      parent_factory.attach_attribute( FakerMaker::Attribute.new( :id, proc { '1' }, required: true ) )
      parent_factory.attach_attribute( FakerMaker::Attribute.new( :wheels, nil, factory: :opt_names_child ) )
      FakerMaker.register_factory( parent_factory )

      result = parent_factory.optional_attribute_names
      expect( result ).to eq [{ wheels: [:brand] }]
    end
  end
end
