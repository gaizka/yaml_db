require File.dirname(__FILE__) + '/base'

describe SerializationHelper::Dump do

	before do
		silence_warnings { ActiveRecord::Base = mock('ActiveRecord::Base', :null_object => true) }
		ActiveRecord::Base.connection = mock('connection')
		ActiveRecord::Base.connection.stub!(:tables).and_return([ 'mytable', 'schema_info', 'schema_migrations' ])
		ActiveRecord::Base.connection.stub!(:columns).with('mytable').and_return([ mock('a',:name => 'a'), mock('b', :name => 'b') ])
		ActiveRecord::Base.connection.stub!(:select_one).and_return({"count"=>"2"})
		ActiveRecord::Base.connection.stub!(:select_all).and_return([ { 'a' => 1, 'b' => 2 }, { 'a' => 3, 'b' => 4 } ])
		SerializationHelper::Utils.stub!(:quote_table).with('mytable').and_return('mytable')
	end

	before(:each) do   
	  File.stub!(:new).with('dump.yml', 'w').and_return(StringIO.new)
	  @io = StringIO.new
	end

	it "should return a list of column names" do
		SerializationHelper::Dump.table_column_names('mytable').should == [ 'a', 'b' ]
	end

	it "should return a list of tables without the rails schema table" do
		SerializationHelper::Dump.tables.should == ['mytable']
	end

	it "should return the total number of records in a table" do
		SerializationHelper::Dump.table_record_count('mytable').should == 2
	end

	it "should return all records from the database and return them when there is only 1 page" do
		SerializationHelper::Dump.each_table_page('mytable') do |records|
			records.should == [ { 'a' => 1, 'b' => 2 }, { 'a' => 3, 'b' => 4 } ]
		end
	end

	it "should paginate records from the database and return them" do
		ActiveRecord::Base.connection.stub!(:select_all).and_return([ { 'a' => 1, 'b' => 2 } ], [ { 'a' => 3, 'b' => 4 } ])

		records = [ ]
		SerializationHelper::Dump.each_table_page('mytable', 1) do |page|
			page.size.should == 1
			records.concat(page)
		end

		records.should == [ { 'a' => 1, 'b' => 2 }, { 'a' => 3, 'b' => 4 } ]
	end

	it "should dump a table's contents to yaml" do
		SerializationHelper::Dump.should_receive(:dump_table_columns)
		SerializationHelper::Dump.should_receive(:dump_table_records)
		SerializationHelper::Dump.dump_table(@io, 'mytable')
	end

	it "should not dump a table's contents when the record count is zero" do
		SerializationHelper::Dump.stub!(:table_record_count).with('mytable').and_return(0)
		SerializationHelper::Dump.should_not_receive(:dump_table_columns)
		SerializationHelper::Dump.should_not_receive(:dump_table_records)
		SerializationHelper::Dump.dump_table(@io, 'mytable')
    end


  context "when configured to only dump selected tables" do
    before do
      ActiveRecord::Base.connection.stub!(:tables).and_return([ 'mytable1', 'mytable2', 'mytable3', 'schema_info', 'schema_migrations' ])
    end

    after do
      # Check expected tables to dump
      SerializationHelper::Dump.tables.sort.should == @expected_tables

      if @expected_tables.size > 0
        @expected_tables.each do |table|
          # Check actual calls to dump_table with expected tables
          SerializationHelper::Dump.should_receive(:dump_table).with(nil, table)
        end
      else
        SerializationHelper::Dump.should_not_receive(:dump_table).with(anything)
      end

      SerializationHelper::Dump.dump(nil)

      # Restore default behaviour
      SerializationHelper::Dump.filter_table_names = nil
    end
    
    it "should dump every table if filter not set" do
      SerializationHelper::Dump.filter_table_names = nil
      @expected_tables =  ['mytable1', 'mytable2', 'mytable3']
    end

    it "should dump matching tables if filter is set as a matching string" do
      SerializationHelper::Dump.filter_table_names = "mytable"
      @expected_tables =  ['mytable1', 'mytable2', 'mytable3']
    end
    
    it "should dump matching tables if filter is set as a regular expression string" do
      SerializationHelper::Dump.filter_table_names = "mytable[1-2]"
      @expected_tables =  ['mytable1', 'mytable2']
    end

    it "should not dump any table if filter does not match any table" do
      SerializationHelper::Dump.filter_table_names = "wadustable"
      @expected_tables =  []
    end
    
  end
end
