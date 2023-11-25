require "airborne"

Airborne.configure do |config|
  config.verify_ssl = false
  #config.base_url = "https://localhost"
  config.base_url = "http://localhost:8080"
end

describe "create container" do
  file = File.read("container1.json")
  payload = JSON.parse(file)
  it "should return a 201" do
    post "/annotations/", payload, { content_type: "application/json", Slug: "my-container" }
    expect_status(201)
    expect_json(type: "AnnotationCollection")
  end
end

describe "get empty collection" do
  it "should contain specific keys and have a total of 0 annotations" do
    get "/annotations/my-container/", { Accept: "application/json" }
    expect_status(404)
  end
end

describe "add 199 annotations to container" do
  file = File.read("annotation1.json")
  payload = JSON.parse(file)
  199.times {
    it "should return a 201" do
      post "/annotations/my-container/", payload, { content_type: "application/json" }
      expect_status(201)
      expect_json(type: "Annotation")
    end
  }
end

describe "check the container collection total" do
  it "should contain 199 annotations" do
    get "/annotations/my-container/", { Accept: "application/json" }
    expect_status(200)
    expect_json(total: 199)
  end
end

describe "get annotation page" do
  it "should contain 199 annotations" do
    get "/annotations/my-container/", { Accept: "application/json", params: { page: 0 } }
    expect_status(200)
    expect_json("partOf", total: 199)
    expect_json_sizes("", items: 199)
    expect_json(type: "AnnotationPage")
  end
end

describe "get the first annotation page" do
  it "should contain 199 annotations" do
    get "/annotations/my-container/", { Accept: "application/json", params: { page: 0 } }
    expect_status(200)
    expect_json("partOf", total: 199)
    expect_json_sizes("", items: 199)
    expect_json(type: "AnnotationPage")
  end
end

describe "get the second annotation page" do
  it "should return a 404" do
    get "/annotations/my-container/", { Accept: "application/json", params: { page: 1 } }
    expect_status(404)
  end
end

describe "add foobar annotation" do
  file = File.read("annotation1.json")
  payload = JSON.parse(file)
  it "should return a 201" do
    post "/annotations/my-container/", payload, { content_type: "application/json", Slug: "foobar" }
    expect_status(201)
    expect_json(type: "Annotation")
  end
end

describe "get foobar annotation" do
  it "should return a 200" do
    get "/annotations/my-container/foobar", { Accept: "application/json" }
    expect_status(200)
    expect_json(type: "Annotation")
  end
end

describe "modify foobar annotation and check for modified key" do
  file = File.read("annotation2.json")
  payload = JSON.parse(file)
  it "should return a 200" do
    put "/annotations/my-container/foobar", payload, { content_type: "application/json" }
    expect_status(200)
    expect_json_keys("", [:modified])
    expect_json(type: "Annotation")
  end
end

describe "delete foobar annotation" do
  it "should return a 204" do
    delete "/annotations/my-container/foobar", { Accept: "application/json" }
    expect_status(204)
  end
end

describe "get the second annotation page" do
  it "should return a 404" do
    get "/annotations/my-container/", { Accept: "application/json", params: { page: 1 } }
    expect_status(404)
  end
end

describe "check the container collection total" do
  it "should contain 199 annotations" do
    get "/annotations/my-container/", { Accept: "application/json" }
    expect_status(200)
    expect_json(total: 199)
  end
end

describe "add 1 annotation to container" do
  file = File.read("annotation1.json")
  payload = JSON.parse(file)
  1.times {
    it "should return a 201" do
      post "/annotations/my-container/", payload, { content_type: "application/json" }
      expect_status(201)
      expect_json(type: "Annotation")
    end
  }
end

describe "check the container collection total and keys" do
  it "should contain 200 annotations and have first and last keys" do
    get "/annotations/my-container/", { Accept: "application/json" }
    expect_status(200)
    expect_json(total: 200)
    expect_json_keys("", [:first])
  end
end

describe "check the first annotation page total and keys" do
  it "should contain 200 annotations items and have a next key" do
    get "/annotations/my-container/", { Accept: "application/json", params: { page: 0 } }
    expect_status(200)
    expect_json("partOf", total: 200)
    expect_json_sizes("", items: 200)
    expect_json(type: "AnnotationPage")
  end
end

describe "check the second annotation page exists" do
  it "should return a 404" do
    get "/annotations/my-container/", { Accept: "application/json", params: { page: 1 } }
    expect_status(404)
  end
end

describe "get container collection items with PreferContainedIRIs" do
  it "should return items as array of strings" do
    get "/annotations/my-container/", { Accept: "application/json", Prefer: "return=representation;include=\"http://www.w3.org/ns/oa#PreferContainedIRIs\"" }
    expect_status(501)
  end
end

describe "get page items with PreferContainedIRIs" do
  it "should return items as array of strings" do
    get "/annotations/my-container/", { Accept: "application/json", params: { page: 0 }, Prefer: "return=representation;include=\"http://www.w3.org/ns/oa#PreferContainedIRIs\"" }
    expect_status(501)
  end
end

describe "get container collection items with PreferContainedDescriptions" do
  it "should return items as array of objects" do
    get "/annotations/my-container/", { Accept: "application/json", Prefer: "return=representation;include=\"http://www.w3.org/ns/oa#PreferContainedDescriptions\"" }
    expect_status(200)
  end
end

describe "get page items with PreferContainedDescriptions" do
  it "should return items as array of objects" do
    get "/annotations/my-container/", { Accept: "application/json", params: { page: 0 }, Prefer: "return=representation;include=\"http://www.w3.org/ns/oa#PreferContainedDescriptions\"" }
    expect_status(200)
  end
end

describe "delete a container" do
  it "should return a 204" do
    delete "/annotations/my-container"
    expect_status(204)
  end
end

describe "crud test on manifest" do
  file = File.read("manifest1.json")
  payload = JSON.parse(file)
  it "POST should return a 201" do
    post "/manifest/foobar", payload, { content_type: "application/json" }
    expect_status(201)
    expect_json(type: "Manifest")
  end
  it "GET should return a 200" do
    get "/manifest/foobar", { Accept: "application/json" }
    expect_status(200)
    expect_json(type: "Manifest")
  end
  file = File.read("manifest2.json")
  it "PUT should return a 200" do
    put "/manifest/foobar", payload, { content_type: "application/json" }
    expect_status(200)
    expect_json(type: "Manifest")
  end
  it "DELETE should return a 204" do
    delete "/manifest/foobar"
    expect_status(204)
  end
end
