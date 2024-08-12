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
