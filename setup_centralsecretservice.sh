#!/bin/bash

# Function to initialize a new Vapor project
initialize_vapor_project() {
    echo "Initializing Vapor project..."
    vapor new CentralSequenceService 
    cd CentralSequenceService || exit
}

# Function to add dependencies to Package.swift
add_dependencies() {
    echo "Adding PostgreSQL dependency..."
    sed -i '' 's/dependencies: \[/dependencies: \[\n    \.package(url: "https:\/\/github.com\/vapor\/fluent-postgres-driver.git", from: "2.1.0"),/' Package.swift

    echo "Updating targets in Package.swift..."
    sed -i '' '/dependencies: \[/a\
                \.product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
    ' Package.swift
}

# Function to configure the PostgreSQL database in configure.swift
configure_postgresql() {
    echo "Configuring PostgreSQL in configure.swift..."
    cat <<EOF >Sources/App/configure.swift
import Fluent
import FluentPostgresDriver
import Vapor

public func configure(_ app: Application) throws {
    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        username: Environment.get("DATABASE_USERNAME") ?? "vapor",
        password: Environment.get("DATABASE_PASSWORD") ?? "password",
        database: Environment.get("DATABASE_NAME") ?? "vapor"
    ), as: .psql)

    app.migrations.add(CreateSequenceElement())

    try routes(app)
}
EOF
}

# Function to create the SequenceElement model
create_model() {
    echo "Creating SequenceElement model..."
    cat <<EOF >Sources/App/Models/SequenceElement.swift
import Fluent
import Vapor

final class SequenceElement: Model, Content {
    static let schema = "sequence_elements"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "element_type")
    var elementType: String
    
    @Field(key: "element_id")
    var elementId: Int
    
    @Field(key: "sequence_number")
    var sequenceNumber: Int
    
    @Field(key: "version_number")
    var versionNumber: Int
    
    init() { }
    
    init(id: UUID? = nil, elementType: String, elementId: Int, sequenceNumber: Int, versionNumber: Int) {
        self.id = id
        self.elementType = elementType
        self.elementId = elementId
        self.sequenceNumber = sequenceNumber
        self.versionNumber = versionNumber
    }
}
EOF
}

# Function to create the migration for the SequenceElement model
create_migration() {
    echo "Creating migration for SequenceElement model..."
    cat <<EOF >Sources/App/Migrations/CreateSequenceElement.swift
struct CreateSequenceElement: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("sequence_elements")
            .id()
            .field("element_type", .string, .required)
            .field("element_id", .int, .required)
            .field("sequence_number", .int, .required)
            .field("version_number", .int, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("sequence_elements").delete()
    }
}
EOF
}

# Function to create the SequenceController
create_controller() {
    echo "Creating SequenceController..."
    cat <<EOF >Sources/App/Controllers/SequenceController.swift
import Fluent
import Vapor

struct SequenceRequest: Content {
    var elementType: String
    var elementId: Int
}

struct ReorderRequest: Content {
    struct Element: Content {
        var elementId: Int
        var newSequence: Int
    }
    var elementType: String
    var elements: [Element]
}

struct VersionRequest: Content {
    struct NewVersionData: Content {
        var text: String
    }
    var elementType: String
    var elementId: Int
    var newVersionData: NewVersionData
}

final class SequenceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let sequence = routes.grouped("sequence")
        sequence.post(use: generateSequenceNumber)
        sequence.post("reorder", use: reorderElements)
        sequence.post("version", use: createVersion)
    }

    func generateSequenceNumber(req: Request) throws -> EventLoopFuture<SequenceElement> {
        let data = try req.content.decode(SequenceRequest.self)
        return SequenceElement.query(on: req.db)
            .filter(\.$elementType == data.elementType)
            .filter(\.$elementId == data.elementId)
            .count()
            .flatMap { count in
                let sequenceElement = SequenceElement(
                    elementType: data.elementType,
                    elementId: data.elementId,
                    sequenceNumber: count + 1,
                    versionNumber: 1
                )
                return sequenceElement.save(on: req.db).map { sequenceElement }
            }
    }

    func reorderElements(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let data = try req.content.decode(ReorderRequest.self)
        let updates = data.elements.map { element in
            SequenceElement.query(on: req.db)
                .filter(\.$elementType == data.elementType)
                .filter(\.$elementId == element.elementId)
                .set(\.$sequenceNumber, to: element.newSequence)
                .update()
        }
        return updates.flatten(on: req.eventLoop).transform(to: .ok)
    }

    func createVersion(req: Request) throws -> EventLoopFuture<SequenceElement> {
        let data = try req.content.decode(VersionRequest.self)
        return SequenceElement.query(on: req.db)
            .filter(\.$elementType == data.elementType)
            .filter(\.$elementId == data.elementId)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { element in
                element.versionNumber += 1
                return element.save(on: req.db).map { element }
            }
    }
}
EOF
}

# Function to set up the routes
setup_routes() {
    echo "Setting up routes..."
    cat <<EOF >Sources/App/routes.swift
import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: SequenceController())
}
EOF
}

# Function to commit and push the project to GitHub
commit_and_push_to_github() {
    echo "Initializing git repository..."
    git init
    git add .
    git commit -m "Initial commit - Central Sequence Service implementation with Vapor and PostgreSQL"
    
    echo "Creating GitHub repository and pushing..."
    gh repo create CentralSequenceService --public --source=. --remote=origin
    git push -u origin main
}

# Main function to call the other functions
main() {
    initialize_vapor_project
    add_dependencies
    configure_postgresql
    create_model
    create_migration
    create_controller
    setup_routes
    commit_and_push_to_github
}

# Execute the main function
main

