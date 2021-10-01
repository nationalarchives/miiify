require "airborne"

Airborne.configure do |config|
  config.verify_ssl = false
  config.base_url = "https://localhost/annotations"
end

describe "create container" do
  file = File.read("container1.json")
  payload = JSON.parse(file)
  it "should return a 201" do
    post "/", payload, { content_type: "application/json", Slug: "my-container" }
    expect_status(201)
    expect_json_types(type: :array_of_strings)
    expect_json(type: ['BasicContainer', 'AnnotationCollection'])
  end
end

describe "get empty collection" do
  it "should contain specific keys and have a total of 0 annotations" do
    get "/my-container/", { Accept: "application/json" }
    expect_status(200)
    expect_json_keys('', [:id, :type])
    expect_json(total: 0)
  end
end


describe "add 199 annotations to container" do
  file = File.read("annotation1.json")
  payload = JSON.parse(file)
  199.times {
    it "should return a 201" do
      post "/my-container/", payload, { content_type: "application/json" }
      expect_status(201)
      expect_json_types(type: :string)
      expect_json(type: 'Annotation')
    end
  }
end

describe "check the container collection total" do
  it "should contain 199 annotations" do
    get "/my-container/", { Accept: "application/json" }
    expect_status(200)
    expect_json(total: 199)
    expect_json_types(type: :array_of_strings)
    expect_json(type: ['BasicContainer', 'AnnotationCollection'])
  end
end

describe "get annotation page" do
  it "should contain 199 annotations" do
    get "/my-container", { Accept: "application/json" }
    expect_status(200)
    expect_json('partOf', total: 199)
    expect_json_sizes('', items: 199)
    expect_json_types(type: :string)
    expect_json(type: 'AnnotationPage')
  end
end

describe "get the first annotation page" do
  it "should contain 199 annotations" do
    get "/my-container", { Accept: "application/json",  params: {page: 0}}
    expect_status(200)
    expect_json('partOf', total: 199)
    expect_json_sizes('', items: 199)
    expect_json_types(type: :string)
    expect_json(type: 'AnnotationPage')
  end
end

describe "get the second annotation page" do
  it "should return a 404" do
    get "/my-container", { Accept: "application/json",  params: {page: 1}}
    expect_status(404)
  end
end

describe "add foobar annotation" do
  file = File.read("annotation1.json")
  payload = JSON.parse(file)
  it "should return a 201" do
    post "/my-container/", payload, { content_type: "application/json", Slug: "foobar" }
    expect_status(201)
    expect_json_types(type: :string)
    expect_json(type: 'Annotation')
  end
end

describe "get foobar annotation" do
  it "should return a 200" do
    get "/my-container/foobar", { Accept: "application/json" }
    expect_status(200)
    expect_json_types(type: :string)
    expect_json(type: 'Annotation')
  end
end

# describe "modify foobar annotation and check for modified key" do
#   file = File.read("annotation2.json")
#   payload = JSON.parse(file)
#   it "should return a 200" do
#     put "/my-container/foobar", payload, { content_type: "application/json" }
#     expect_status(200)
#     expect_json_keys('', [:modified])
#     expect_json_types(type: :string)
#     expect_json(type: 'Annotation')
#   end
# end

describe "delete foobar annotation" do
  it "should return a 204" do
    delete "/my-container/foobar", { Accept: "application/json" }
    expect_status(204)
  end
end

describe "get the second annotation page" do
  it "should return a 404" do
    get "/my-container", { Accept: "application/json",  params: {page: 1}}
    expect_status(404)
  end
end

describe "check the container collection total" do
  it "should contain 199 annotations" do
    get "/my-container/", { Accept: "application/json" }
    expect_status(200)
    expect_json(total: 199)
    expect_json_types(type: :array_of_strings)
    expect_json(type: ['BasicContainer', 'AnnotationCollection'])
  end
end

describe "add 1 annotation to container" do
  file = File.read("annotation1.json")
  payload = JSON.parse(file)
  1.times {
    it "should return a 201" do
      post "/my-container/", payload, { content_type: "application/json" }
      expect_status(201)
      expect_json_types(type: :string)
      expect_json(type: 'Annotation')
    end
  }
end

describe "check the container collection total and keys" do
  it "should contain 200 annotations and have first and last keys" do
    get "/my-container/", { Accept: "application/json" }
    expect_status(200)
    expect_json(total: 200)
    expect_json_keys('', [:first])
    expect_json_keys('', [:last])
    expect_json_types(type: :array_of_strings)
    expect_json(type: ['BasicContainer', 'AnnotationCollection'])
  end
end

describe "check the first annotation page total and keys" do
  it "should contain 200 annotations items and have a next key" do
    get "/my-container", { Accept: "application/json" }
    expect_status(200)
    expect_json('partOf', total: 200)
    expect_json_sizes('', items: 200)
    expect_json_keys('', [:next])
    expect_json_types(type: :string)
    expect_json(type: 'AnnotationPage')
  end
end

describe "check the second annotation page total and keys" do
  it "should contain 0 annotations items and have a prev key" do
    get "/my-container", { Accept: "application/json", params: {page: 1} }
    expect_status(200)
    expect_json('partOf', total: 200)
    expect_json_sizes('', items: 0)
    expect_json_keys('', [:prev])
    expect_json_types(type: :string)
    expect_json(type: 'AnnotationPage')
  end
end

describe "delete a container" do
  it "should return a 204" do
    delete "/my-container/"
    expect_status(204)
  end
end